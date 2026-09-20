import SwiftUI

/// A rounded surface card used to group settings content on the warm canvas.
struct KGCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KGColor.surface, in: RoundedRectangle(cornerRadius: KGRadius.group, style: .continuous))
            .kgShadow(.card)
    }
}

/// A settings list row: tinted icon tile + title + optional trailing value + chevron.
struct SettingsRow: View {
    let icon: String
    var iconTint: Color = KGColor.accent
    var iconBg: Color = KGColor.accentTint
    let title: LocalizedStringKey
    var value: String? = nil
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 29, height: 29)
                .background(iconBg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title).font(KGFont.row).foregroundStyle(KGColor.ink)
            Spacer(minLength: 8)
            if let value {
                Text(value).font(KGFont.row).foregroundStyle(KGColor.ink2)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KGColor.ink3)
            }
        }
        .contentShape(Rectangle())
    }
}

/// The KeyGlot / Custom segmented control.
struct SegmentedModePicker: View {
    @Binding var mode: AIMode

    var body: some View {
        HStack(spacing: 4) {
            segment(.keyglot, "KeyGlot")
            segment(.custom, "Custom")
        }
        .padding(4)
        .background(KGColor.fill, in: RoundedRectangle(cornerRadius: KGRadius.group, style: .continuous))
    }

    private func segment(_ value: AIMode, _ title: LocalizedStringKey) -> some View {
        let selected = mode == value
        return Text(title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(selected ? Color.white : KGColor.ink2)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                selected ? AnyShapeStyle(KGColor.ink) : AnyShapeStyle(Color.clear),
                in: RoundedRectangle(cornerRadius: KGRadius.button, style: .continuous)
            )
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { mode = value } }
    }
}

/// The green "Pro" pill shown when subscribed.
struct ProBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 11, weight: .bold))
            Text("Pro").font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(KGColor.success)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(KGColor.successBg, in: Capsule())
    }
}

/// The small gradient logo tile (uses the bundled mark if present, else a gradient placeholder).
struct LogoMark: View {
    var size: CGFloat = 34
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            .fill(KGGradient.diagonal)
            .frame(width: size, height: size)
            .overlay(
                Image("keyglot-mark")
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.29, style: .continuous))
            )
    }
}
