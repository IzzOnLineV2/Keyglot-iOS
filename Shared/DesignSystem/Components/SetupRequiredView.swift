import SwiftUI

/// A friendly full-screen "you need to set this up first" state, used instead of a raw error when a
/// feature is opened before the AI is ready (no Pro subscription, or Custom without the needed key).
struct SetupRequiredView: View {
    var icon: String = "sparkles"
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ZStack {
            KGColor.canvas.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Circle().fill(KGColor.accentTint).frame(width: 92, height: 92)
                    .overlay(Image(systemName: icon).font(.system(size: 38)).foregroundStyle(KGColor.accent))
                Text(title)
                    .font(KGFont.serif(30, style: .title1))
                    .foregroundStyle(KGColor.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(KGFont.body).foregroundStyle(KGColor.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.kgPrimary)
                        .padding(.top, 6)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
    }
}
