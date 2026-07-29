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
        .description("Tap to listen and translate what you hear.")
        .supportedFamilies([.systemSmall])
    }
}

struct KeyglotEntry: TimelineEntry {
    let date: Date
}

/// The widget is static (no data) — it's just a launcher button.
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
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 60, height: 60)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
                Text("Listen")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
