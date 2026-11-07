import SwiftUI

/// 付费墙 —— 对应 Figma `T-13-01 付费墙·买断` / `T-13-02 购买成功·已解锁`。
///
/// 触发点只有三处（都不在启动路径）：建第 2 个词库、词条超过 500、设置里主动点升级。
@MainActor
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var purchase = PurchaseService.shared

    let reason: UpgradeReason
    var onUnlocked: () -> Void = {}

    private let benefits: [(String, String)] = [
        ("books.vertical", "无限词库"),
        ("text.line.first.and.arrowtriangle.forward", "无限词条"),
        ("calendar.badge.clock", "自定义每日新词"),
        ("arrow.triangle.2.circlepath", "永久可用 · 可恢复")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    priceCard
                        .padding(.top, 24)
                    benefitList
                        .padding(.top, 20)
                    actions
                        .padding(.top, 24)
                }
                .padding(.horizontal, Theme.Spacing.screenH)
                .padding(.bottom, 32)
            }
            .background(Theme.Palette.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .task { await purchase.loadProduct() }
            .alert("提示", isPresented: Binding(
                get: { purchase.errorMessage != nil },
                set: { if !$0 { purchase.errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { purchase.errorMessage = nil }
            } message: {
                Text(purchase.errorMessage ?? "")
            }
        }
    }

    // MARK: - 顶部

    private var hero: some View {
        VStack(spacing: 10) {
            AnimalView(animal: .juzi, size: 116, expression: .happy, animated: true)
                .padding(.top, 12)
            Text(reason.title)
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(reason.message)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 价格

    private var priceCard: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(purchase.displayPrice)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("一次性 · 不订阅")
                    .font(Theme.Font.bodySmall)
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            Text("付一次，永久解锁；换设备用「恢复购买」找回来")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.Palette.surface)
        )
    }

    private var benefitList: some View {
        VStack(spacing: 12) {
            ForEach(benefits, id: \.0) { item in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Palette.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.1)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text(detail(for: item.0))
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    Spacer()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: Theme.Radius.tile, shadowed: false)
    }

    private func detail(for key: String) -> String {
        switch key {
        case "books.vertical": return "免费版 1 个自建词库，解锁后不限"
        case "text.line.first.and.arrowtriangle.forward": return "免费版 500 个词条，解锁后不限"
        case "calendar.badge.clock": return "免费版每天最多 20 个新词"
        default: return "家庭共享可用，退款由 App Store 处理"
        }
    }

    // MARK: - 按钮

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    if await purchase.purchase() {
                        onUnlocked()
                        dismiss()
                    }
                }
            } label: {
                if purchase.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("\(purchase.displayPrice) 解锁全部")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(purchase.isLoading)

            Button("恢复购买") {
                Task {
                    if await purchase.restore() {
                        onUnlocked()
                        dismiss()
                    }
                }
            }
            .buttonStyle(SecondaryButtonStyle())

            Text("付款通过 App Store 完成，开发者拿不到你的支付信息。\n退款由 Apple 处理，退款后权益会收回，但你的词库不会被删除。")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }
}

#Preview("付费墙") {
    PaywallView(reason: .wordLimit)
        .modelContainer(BeanManStore.makePreviewContainer())
}