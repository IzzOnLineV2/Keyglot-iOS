import WidgetKit
import SwiftUI
import AppIntents

/// A one-tap "Listen & translate" widget: the mic button runs `OpenListenIntent`, which opens the
/// app straight into the Listen screen (which starts recording immediately).
struct KeyglotListenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KeyglotListen", provider: KeyglotProvider()) { _ in
            KeyglotListenWidgetView()
        }
        .configurationDisplayName("Keyglot")
        .description(Text("Tap to listen and translate what you hear."))
        .supportedFamilies([.systemSmall])
    }
}

struct KeyglotEntry: TimelineEntry {
    let date: Date
}

/// The widget is static (no data), it's just a launcher button.
struct KeyglotProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeyglotEntry { KeyglotEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (KeyglotEntry) -> Void) {
        completion(KeyglotEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeyglotEntry>) -> Void) {
        completion(Timeline(entries: [KeyglotEntry(date: Date())], policy: .never))
    }
}

struct KeyglotListenWidgetView: View {
    var body: some View {
        Button(intent: OpenListenIntent()) {
            VStack(spacing: 10) {
                Circle()
                    .fill(KGGradient.diagonal)
                    .frame(width: 58, height: 58)
                    .overlay(Image(systemName: "mic.fill").font(.system(size: 24)).foregroundStyle(.white))
                Text("Listen & translate")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(hex: 0x3E2E63), Color(hex: 0x1B2B48)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}
