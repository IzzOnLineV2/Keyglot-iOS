import SwiftUI
import AVFoundation

/// Drives the in-app "Listen & translate" screen: record from the mic, auto-stop on silence, then
/// send the clip to Gemini (which handles dialects like Darija) and show the translation.
///
/// No live/streaming ASR and no Apple Speech, we record a short clip and let Gemini "listen".
@MainActor
final class ListenViewModel: NSObject, ObservableObject {

    enum Phase: Equatable {
        case idle
        case recording
        case processing
        case result(transcript: String, translation: String)
        case noSpeech   // recorded, but nothing intelligible was heard (gentle "too quiet" state)
        case failed(String)
    }

    @Published var phase: Phase = .idle
    /// 0...1 mic level for the pulsing UI.
    @Published var level: CGFloat = 0
    /// Seconds elapsed in the current recording, for the live timer.
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var selectedID = AppGroupStorage.shared.audioLanguageID
    /// Target language the result is translated into ("you read"). "auto" = device language.
    @Published var targetID = AppGroupStorage.shared.audioTargetID
    /// Whether read-aloud is currently speaking, for the button toggle.
    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var meterTimer: Timer?
    private var startedAt: Date?
    private var silenceStart: Date?
    private var hasSpoken = false
    /// Loudest peak seen during the recording, to tell a real recording from true silence.
    private var maxPeak: Float = -160

    // Silence auto-stop tuning, using PEAK power (dBFS; peaks for close speech reach roughly -25…-10).
    private let speechThreshold: Float = -30   // above this a peak counts as speech
    private let silenceThreshold: Float = -45  // below this counts as silence (for auto-stop)
    private let noiseFloor: Float = -50        // if the loudest peak stays under this, it was true silence
    private let silenceDuration: TimeInterval = 1.4
    private let maxDuration: TimeInterval = 30

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Control

    /// Ask for mic permission (first time) and start recording immediately.
    func start() {
        stopSpeaking()
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard granted else {
                    self.phase = .failed(String(localized: "Microphone access is off. Enable it in Settings."))
                    return
                }
                self.beginRecording()
            }
        }
    }

    func stop() {
        guard phase == .recording else { return }
        meterTimer?.invalidate(); meterTimer = nil
        recorder?.stop(); recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // Only treat it as silence if the loudest peak never rose above the noise floor. This is
        // permissive on purpose: if there was any real sound we send it and let the model decide,
        // rather than wrongly rejecting valid speech.
        guard maxPeak > noiseFloor else {
            if let fileURL { try? FileManager.default.removeItem(at: fileURL); self.fileURL = nil }
            level = 0
            phase = .noSpeech
            return
        }
        Task { await process() }
    }

    /// Discard any recording and go back to idle (used when leaving the screen).
    func cancel() {
        stopSpeaking()
        meterTimer?.invalidate(); meterTimer = nil
        recorder?.stop(); recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        level = 0
        phase = .idle
    }

    func setLanguage(_ id: String) {
        selectedID = id
        AppGroupStorage.shared.audioLanguageID = id
    }

    func setTarget(_ id: String) {
        targetID = id
        AppGroupStorage.shared.audioTargetID = id
    }

    // MARK: - Read aloud (on-device TTS, no network)

    /// Speak the given text in the target language's voice, or stop if already speaking.
    func toggleSpeak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: VoiceLanguage.targetVoiceCode(for: targetID))
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    // MARK: - Recording

    private func beginRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true, options: [])

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.record()

            recorder = rec
            fileURL = url
            startedAt = Date()
            silenceStart = nil
            hasSpoken = false
            maxPeak = -160
            level = 0
            elapsed = 0
            phase = .recording

            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func tick() {
        guard let rec = recorder, rec.isRecording else { return }
        rec.updateMeters()
        let peak = rec.peakPower(forChannel: 0)
        maxPeak = max(maxPeak, peak)
        level = CGFloat(max(0, min(1, (peak + 50) / 50)))
        if let startedAt { elapsed = Date().timeIntervalSince(startedAt) }

        if let startedAt, Date().timeIntervalSince(startedAt) > maxDuration { stop(); return }

        // Don't arm the silence auto-stop in the first second (meters read low right after record()).
        let warmedUp = (startedAt.map { Date().timeIntervalSince($0) > 1.0 }) ?? false

        if peak > speechThreshold {
            hasSpoken = true
            silenceStart = nil
        } else if hasSpoken, warmedUp, peak < silenceThreshold {
            if let s = silenceStart {
                if Date().timeIntervalSince(s) > silenceDuration { stop() }
            } else {
                silenceStart = Date()
            }
        }
    }

    // MARK: - Translate

    private func process() async {
        guard let fileURL else { phase = .idle; return }
        defer { try? FileManager.default.removeItem(at: fileURL); self.fileURL = nil }

        phase = .processing
        do {
            let translator = try AIResolver.audioTranslator()   // KeyGlot backend or user's Gemini key
            let result = try await translator.translate(
                fileURL: fileURL,
                mimeType: "audio/mp4",
                targetLanguage: VoiceLanguage.targetEnglishName(for: targetID),
                sourceHint: VoiceLanguage.hint(for: selectedID)
            )
            let transcript = result.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            let translation = result.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            if transcript.isEmpty && translation.isEmpty {
                phase = .noSpeech
                return
            }
            phase = .result(transcript: result.transcript, translation: result.translation)
            AppGroupStorage.shared.recordUse()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

extension ListenViewModel: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
