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
        .supportedFamilies([.systemSmall, .systemMedium])
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
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Button(intent: OpenListenIntent()) {
            if family == .systemMedium { mediumContent } else { smallContent }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(hex: 0x3E2E63), Color(hex: 0x1B2B48)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    // Small: centered mic + label.
    private var smallContent: some View {
        VStack(spacing: 10) {
            micCircle(58, glyph: 24)
            Text("Listen & translate")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    // Medium (double width): mic on the left, title + hint on the right.
    private var mediumContent: some View {
        HStack(spacing: 16) {
            micCircle(52, glyph: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text("Listen & translate")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Tap and it's already recording")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func micCircle(_ size: CGFloat, glyph: CGFloat) -> some View {
        Circle()
            .fill(KGGradient.diagonal)
            .frame(width: size, height: size)
            .overlay(Image(systemName: "mic.fill").font(.system(size: glyph)).foregroundStyle(.white))
    }
}
