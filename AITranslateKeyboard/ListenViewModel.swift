import SwiftUI
import AVFoundation

/// Drives the in-app "Listen & translate" screen: record from the mic, auto-stop on silence, then
/// send the clip to Gemini (which handles dialects like Darija) and show the translation.
///
/// No live/streaming ASR and no Apple Speech — we record a short clip and let Gemini "listen".
@MainActor
final class ListenViewModel: NSObject, ObservableObject {

    enum Phase: Equatable {
        case idle
        case recording
        case processing
        case result(transcript: String, translation: String)
        case failed(String)
    }

    @Published var phase: Phase = .idle
    /// 0...1 mic level for the pulsing UI.
    @Published var level: CGFloat = 0
    @Published var selectedID = AppGroupStorage.shared.audioLanguageID

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var meterTimer: Timer?
    private var startedAt: Date?
    private var silenceStart: Date?
    private var hasSpoken = false

    // Silence auto-stop tuning (dBFS; recorder power runs roughly -60…0).
    private let speechThreshold: Float = -22
    private let silenceThreshold: Float = -35
    private let silenceDuration: TimeInterval = 1.4
    private let maxDuration: TimeInterval = 30

    // MARK: - Control

    /// Ask for mic permission (first time) and start recording immediately.
    func start() {
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
        Task { await process() }
    }

    /// Discard any recording and go back to idle (used when leaving the screen).
    func cancel() {
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
            level = 0
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
        let power = rec.averagePower(forChannel: 0)
        level = CGFloat(max(0, min(1, (power + 50) / 50)))

        if let startedAt, Date().timeIntervalSince(startedAt) > maxDuration { stop(); return }

        if power > speechThreshold {
            hasSpoken = true
            silenceStart = nil
        } else if hasSpoken, power < silenceThreshold {
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

        guard let key = CredentialStore.shared.apiKey(for: .gemini) else {
            phase = .failed(String(localized: "Add a Google Gemini API key in Settings to translate what you hear."))
            return
        }

        phase = .processing
        do {
            let result = try await GeminiAudioTranslator(apiKey: key).translate(
                fileURL: fileURL,
                mimeType: "audio/mp4",
                targetLanguage: VoiceLanguage.deviceLanguageEnglishName,
                sourceHint: VoiceLanguage.hint(for: selectedID)
            )
            phase = .result(transcript: result.transcript, translation: result.translation)
            AppGroupStorage.shared.recordUse()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
