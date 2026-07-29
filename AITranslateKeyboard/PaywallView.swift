import SwiftUI
import StoreKit

/// The dismissible "Support Keyglot" reminder. Nothing is gated — the user can always continue for
/// free; a one-time purchase removes the reminder for good.
struct PaywallView: View {
    @ObservedObject var store: StoreManager
    let onDismiss: () -> Void

    @State private var busy = false

    private var priceText: String { store.product?.displayPrice ?? "€4,99" }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Text("💚").font(.system(size: 60))
            Text("Support Keyglot")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("Keyglot is free and open source. A one-time purchase removes this reminder and helps me keep improving it.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
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
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy || store.product == nil)

                Button("Continue for free", action: onDismiss)
                    .font(.subheadline)

                Button("Restore purchases") {
                    Task {
                        await store.restore()
                        if store.isSupporter { onDismiss() }
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Link("Terms & Privacy", destination: URL(string: "https://izzonline.it")!)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding()
        .overlay {
            if busy { ProgressView().scaleEffect(1.3) }
        }
        .interactiveDismissDisabled(busy)
        .onChange(of: store.isSupporter) { _, supporter in
            if supporter { onDismiss() }
        }
    }
}
