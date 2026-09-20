import SwiftUI
import StoreKit

/// The dismissible "Support Keyglot" reminder. Nothing is gated — the user can always continue for
/// free; a one-time purchase removes the reminder for good.
struct PaywallView: View {
    @ObservedObject var store: StoreManager
    let onDismiss: () -> Void

    @State private var busy = false

    // Fallback shown only until the real App Store Connect price loads (set the product to €1,99).
    private var priceText: String { store.product?.displayPrice ?? "€1,99" }

    var body: some View {
        ZStack {
            KGColor.canvas.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()

                LogoMark(size: 64)
                Text("Support Keyglot")
                    .font(KGFont.serif(34, style: .largeTitle))
                    .foregroundStyle(KGColor.ink)
                    .multilineTextAlignment(.center)
                Text("Keyglot is free and open source. A one-time purchase removes this reminder and helps me keep improving it.")
                    .font(KGFont.body)
                    .foregroundStyle(KGColor.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task {
                            busy = true
                            await store.purchase()
                            busy = false
                            if store.isSupporter { onDismiss() }
                        }
                    } label: {
                        Text("Unlock forever · \(priceText)")
                    }
                    .buttonStyle(.kgPrimary)
                    .disabled(busy || store.product == nil)

                    Button("Continue for free", action: onDismiss)
                        .font(KGFont.row).foregroundStyle(KGColor.ink2)

                    Button("Restore purchases") {
                        Task {
                            await store.restore()
                            if store.isSupporter { onDismiss() }
                        }
                    }
                    .font(KGFont.caption).foregroundStyle(KGColor.ink3)
                }

                Link("Terms & Privacy", destination: URL(string: "https://izzonline.it")!)
                    .font(KGFont.caption).foregroundStyle(KGColor.ink3)
                    .padding(.top, 2)
            }
            .padding(24)
            .overlay { if busy { SpinnerRing(size: 40) } }
        }
        .interactiveDismissDisabled(busy)
        .onChange(of: store.isSupporter) { _, supporter in
            if supporter { onDismiss() }
        }
    }
}
