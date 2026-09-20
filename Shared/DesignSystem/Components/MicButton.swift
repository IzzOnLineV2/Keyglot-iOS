import SwiftUI

/// The big circular mic used on "Listen & translate". Idle = ink circle with a mic; listening =
/// record-colored circle with pulsing rings + equalizer bars; processing = neutral circle with a
/// spinner. The circle never moves between states.
struct MicButton: View {
    enum MicState { case idle, listening, processing }

    let state: MicState
    var level: CGFloat = 0
    var action: () -> Void = {}

    private let diameter: CGFloat = 132

    var body: some View {
        Button(action: action) {
            ZStack {
                if state == .listening {
                    PulseRing(diameter: diameter)
                    PulseRing(diameter: diameter, delay: 0.95)
                }
                Circle()
                    .fill(fillColor)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(state == .listening ? 1 + level * 0.15 : 1)
                    .kgShadow(state == .listening ? .micLive : .micIdle)
                    .animation(.easeOut(duration: 0.12), value: level)
                content
            }
            .frame(width: diameter * 1.9, height: diameter * 1.9)   // room for the pulse rings
        }
        .buttonStyle(.plain)
        .disabled(state == .processing)
        .accessibilityLabel(Text(state == .listening ? "Stop listening" : "Start listening"))
    }

    private var fillColor: Color {
        switch state {
        case .idle:       return KGColor.ink
        case .listening:  return KGColor.record
        case .processing: return KGColor.fill
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            Image(systemName: "mic.fill").font(.system(size: 46)).foregroundStyle(.white)
        case .listening:
            EqualizerBars(color: .white)
        case .processing:
            SpinnerRing()
        }
    }
}

/// An expanding, fading ring behind the live mic.
struct PulseRing: View {
    var diameter: CGFloat = 132
    var delay: Double = 0
    @State private var animate = false

    var body: some View {
        Circle()
            .stroke(KGColor.record.opacity(0.55), lineWidth: 3)
            .frame(width: diameter, height: diameter)
            .scaleEffect(animate ? 1.9 : 1)
            .opacity(animate ? 0 : 0.55)
            .onAppear {
                withAnimation(.easeOut(duration: 1.9).repeatForever(autoreverses: false).delay(delay)) {
                    animate = true
                }
            }
    }
}

/// Five bars bouncing like an equalizer while recording.
struct EqualizerBars: View {
    var color: Color = .white
    private let peaks: [CGFloat] = [0.45, 0.75, 1.0, 0.6, 0.5]
    @State private var animate = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(peaks.indices, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 5, height: 46)
                    .scaleEffect(y: animate ? peaks[i] : 0.28, anchor: .center)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.12),
                        value: animate
                    )
            }
        }
        .frame(height: 46)
        .onAppear { animate = true }
    }
}

/// A rotating three-quarter arc spinner in the accent color.
struct SpinnerRing: View {
    var size: CGFloat = 34
    @State private var rotate = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(KGColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { rotate = true }
            }
    }
}
