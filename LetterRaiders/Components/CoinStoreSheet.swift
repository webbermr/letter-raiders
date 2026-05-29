import StoreKit
import SwiftUI

struct CoinStoreSheet: View {
    let onDismiss: () -> Void

    @ObservedObject private var store = CoinStore.shared
    @AppStorage(Hangar.coinKey) private var coins: Int = Hangar.startingCoins

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GameBackground(variant: .cosmos)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("GET COINS")
                        .font(AppFont.mono(11, weight: .bold))
                        .tracking(3)
                        .foregroundColor(Theme.cyanSoft)

                    HStack(alignment: .lastTextBaseline) {
                        Text("Coin Bay")
                            .font(AppFont.display(30, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        coinBalance
                    }

                    Text("Buy coins for ships, lives, ZAP, and WILD. Purchases are handled securely by the App Store.")
                        .font(AppFont.mono(11, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)

                    VStack(spacing: 10) {
                        ForEach(CoinPack.allCases) { pack in
                            packRow(pack)
                        }
                    }

                    if let message = store.message {
                        Text(message)
                            .font(AppFont.mono(10.5, weight: .regular))
                            .foregroundColor(Theme.yellow.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 22)
                .padding(.top, 60)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Haptics.select()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .preferredColorScheme(.dark)
        .task {
            await store.loadProducts()
        }
    }

    private var coinBalance: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.yellow)
                .frame(width: 9, height: 9)
                .shadow(color: Theme.yellow, radius: 4)
            Text("\(coins)")
                .font(AppFont.mono(12, weight: .bold))
                .tracking(1.3)
                .foregroundColor(Theme.yellow)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Theme.yellow.opacity(0.11))
                .overlay(Capsule().stroke(Theme.yellow.opacity(0.3), lineWidth: 1))
        )
    }

    private func packRow(_ pack: CoinPack) -> some View {
        let product = store.product(for: pack)
        let isPurchasing = store.purchasingProductID == pack.productID
        let disabled = product == nil || store.purchasingProductID != nil || store.isLoading
        return Button {
            Task { await store.purchase(pack) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.yellow.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(Theme.yellow)
                        .frame(width: 16, height: 16)
                        .shadow(color: Theme.yellow.opacity(0.8), radius: 7)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(pack.name)
                            .font(AppFont.display(14, weight: .semibold))
                            .foregroundColor(.white)
                        if let badge = pack.badge {
                            Text(badge)
                                .font(AppFont.mono(7.5, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(Theme.void)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.yellow))
                        }
                    }
                    Text("\(pack.coins.formatted()) COINS")
                        .font(AppFont.mono(10.5, weight: .regular))
                        .tracking(1.5)
                        .foregroundColor(Color.white.opacity(0.58))
                }

                Spacer(minLength: 8)

                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(store.isLoading ? "..." : product?.displayPrice ?? "N/A")
                        .font(AppFont.mono(12, weight: .bold))
                        .foregroundColor(product == nil ? Color.white.opacity(0.35) : Theme.yellow)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.045))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.yellow.opacity(disabled ? 0.12 : 0.34), lineWidth: 1))
            )
            .opacity(disabled && !isPurchasing ? 0.62 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
