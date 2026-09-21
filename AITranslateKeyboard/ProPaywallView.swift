import SwiftUI
import StoreKit

/// KeyGlot Pro subscription screen (design 05 · Onboarding & subscription, screen 3). Shown as the
/// final onboarding step and reusable as a standalone paywall. Prices come from StoreKit, never
/// hardcoded; the user can always skip and use Custom (BYOK) for free.
struct ProPaywallView: View {
    @EnvironmentObject private var subscription: SubscriptionManager
    /// Called when the user subscribes, restores into a subscription, or skips.
    let onClose: () -> Void

    @State private var selectedID: String?
    @State private var busy = false

    private var yearly: Product? { subscription.products.first { $0.id.hasSuffix("yearly") } }
    private var monthly: Product? { subscription.products.first { $0.id.hasSuffix("monthly") } }
    private var selected: Product? {
        subscription.products.first { $0.id == selectedID } ?? yearly ?? monthly ?? subscription.products.first
    }

    var body: some View {
        ZStack {
            KGColor.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        LogoMark(size: 58)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("KeyGlot Pro").font(KGFont.serif(34, style: .largeTitle)).foregroundStyle(KGColor.ink)
                            Text("Every translation, rewrite and voice note, with the AI included. Nothing else to sign up for.")
                                .font(KGFont.body).foregroundStyle(KGColor.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        benefits
                        plans
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
                }
                footer
            }
        }
        .onAppear {
            if selectedID == nil { selectedID = (yearly ?? monthly)?.id }
        }
        .onChange(of: subscription.products.map(\.id)) { _, _ in
            if selectedID == nil { selectedID = (yearly ?? monthly)?.id }
        }
        .onChange(of: subscription.isSubscribed) { _, subscribed in
            if subscribed { onClose() }
        }
        .interactiveDismissDisabled(busy)
    }

    // MARK: - Header (close)

    private var header: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KGColor.ink2)
                    .frame(width: 30, height: 30)
                    .background(KGColor.fill, in: Circle())
            }
            .disabled(busy)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 11) {
            benefit("Keyboard translation & tone rewrites")
            benefit("Voice notes, dialects included")
            benefit("Listen & translate, on every device you own")
        }
    }

    private func benefit(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(KGColor.success)
            Text(text).font(KGFont.row).foregroundStyle(KGColor.ink)
        }
    }

    // MARK: - Plans

    @ViewBuilder private var plans: some View {
        if subscription.products.isEmpty {
            Text("Loading plans…").font(KGFont.row).foregroundStyle(KGColor.ink2)
        } else {
            VStack(spacing: 11) {
                if let yearly { planRow(yearly, subtitle: yearlySubtitle(yearly), badge: savingsBadge()) }
                if let monthly { planRow(monthly, subtitle: monthlySubtitle(monthly), badge: nil) }
            }
        }
    }

    private func planRow(_ product: Product, subtitle: String, badge: String?) -> some View {
        let isSelected = (selected?.id == product.id)
        return Button { selectedID = product.id } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(planName(product)).font(KGFont.row.weight(.semibold)).foregroundStyle(KGColor.ink)
                    Text(subtitle).font(KGFont.caption).foregroundStyle(KGColor.ink2)
                }
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(KGColor.success, in: Capsule())
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KGColor.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(isSelected ? KGColor.ink : KGColor.border, lineWidth: isSelected ? 2 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func planName(_ product: Product) -> LocalizedStringKey {
        product.id.hasSuffix("yearly") ? "Yearly" : "Monthly"
    }

    // MARK: - Footer (CTA + fine print)

    private var footer: some View {
        VStack(spacing: 10) {
            Button { subscribe() } label: {
                if let selected {
                    Text("Subscribe · \(selected.displayPrice)")
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.kgGradient)
            .disabled(busy || subscription.products.isEmpty)
            .overlay { if busy { SpinnerRing(size: 22) } }

            Text("No free trial to forget about, no ads. Prefer your own AI key? Custom mode is free, in Advanced.")
                .font(KGFont.caption).foregroundStyle(KGColor.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                Button("Restore") { Task { busy = true; await subscription.restore(); busy = false } }
                Link("Terms", destination: URL(string: "https://izzonline.it")!)
                Link("Privacy", destination: URL(string: "https://izzonline.it")!)
            }
            .font(KGFont.caption).foregroundStyle(KGColor.ink3)
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private func subscribe() {
        guard let product = selected else { onClose(); return }
        Task {
            busy = true
            _ = try? await subscription.purchase(product)
            if subscription.isSubscribed { await activateKeyGlot() }
            busy = false
            if subscription.isSubscribed { onClose() }
        }
    }

    /// Buying Pro means you want the included AI: switch to KeyGlot mode (a Custom user's key stays
    /// in the Keychain, so they can switch back in Advanced) and mint the backend session now so the
    /// keyboard/extensions work immediately, without waiting for the next app launch.
    private func activateKeyGlot() async {
        AppGroupStorage.shared.aiMode = .keyglot
        if let jws = await subscription.currentEntitlementJWS() {
            _ = try? await KeyGlotSession().exchange(jws: jws)
        }
    }

    // MARK: - Price helpers (computed from StoreKit, never hardcoded)

    /// "€24,99 · about €2,08 a month"
    private func yearlySubtitle(_ product: Product) -> String {
        let perMonth = (product.price / 12).formatted(product.priceFormatStyle)
        let monthly = String(localized: "about \(perMonth) a month")
        return "\(product.displayPrice) · \(monthly)"
    }

    /// "€2,99 · cancel whenever"
    private func monthlySubtitle(_ product: Product) -> String {
        "\(product.displayPrice) · \(String(localized: "cancel whenever"))"
    }

    /// "Save 30%" computed from yearly vs 12× monthly, or nil when it can't be computed.
    private func savingsBadge() -> String? {
        guard let y = yearly, let m = monthly else { return nil }
        let fullYear = m.price * 12
        guard fullYear > 0 else { return nil }
        let saved = (fullYear - y.price) / fullYear
        let percent = Int((saved as NSDecimalNumber).doubleValue * 100)
        guard percent > 0 else { return nil }
        let pct = "\(percent)%"
        return String(localized: "Save \(pct)")
    }
}
