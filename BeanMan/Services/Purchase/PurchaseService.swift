import Foundation
import Observation
import StoreKit

/// 内购：一次性买断（非消耗型）。
///
/// 三条硬规则：
/// 1. **只信 Apple 的签名**——`isPro` 的真相来自 `Transaction.currentEntitlements`，
///    本地缓存只用于首屏不闪，拿到真实结果后立即覆盖。
/// 2. **必须能恢复**——App Store 审核 3.1.1 的硬性要求，`restore()` 走 `AppStore.sync()`。
/// 3. **退款要回收**——监听 `revocationDate`，回收权益但**不删用户数据**。
@MainActor
@Observable
final class PurchaseService {

    static let shared = PurchaseService()

    /// 产品 ID 一旦上架就不能改；改价可以，改 ID 等于换了新商品。
    static let proProductID = "com.yourname.beanman.pro"

    private(set) var product: Product?
    private(set) var isPro: Bool
    private(set) var isLoading = false

    /// 商品信息拉取失败（常见于模拟器没配 StoreKit 配置文件），不影响其他功能。
    private(set) var loadError: String?
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var started = false

    private static let cacheKey = "purchase.pro.cached.v1"

    private init() {
        isPro = UserDefaults.standard.bool(forKey: Self.cacheKey)
    }

    // MARK: - 生命周期

    /// App 启动时调一次：先读缓存（首屏不闪），再向 Apple 核实，最后订阅交易更新。
    func start() {
        guard !started else { return }
        started = true

        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }

        Task {
            await refreshEntitlement()
            await loadProduct()
        }
    }

    // MARK: - 商品

    func loadProduct() async {
        guard product == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
            loadError = products.isEmpty ? "没有取到商品信息（检查 App Store Connect 是否已建好这个内购）" : nil
        } catch {
            loadError = "取商品信息失败：\(error.localizedDescription)"
        }
    }

    var displayPrice: String {
        product?.displayPrice ?? "¥6"
    }

    // MARK: - 购买 / 恢复

    @discardableResult
    func purchase() async -> Bool {
        if product == nil { await loadProduct() }
        guard let product else {
            errorMessage = loadError ?? "暂时买不了，请稍后再试"
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "购买凭据校验失败，已中止"
                    return false
                }
                await transaction.finish()
                await refreshEntitlement()
                return isPro
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "购买正在等待批准，批准后会自动解锁"
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "购买失败：\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = "恢复失败：\(error.localizedDescription)"
            return false
        }
        await refreshEntitlement()
        if !isPro { errorMessage = "这台 Apple ID 上没有找到购买记录" }
        return isPro
    }

    /// 以 `currentEntitlements` 为准重算权益；已退款的交易不算。
    func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.proProductID else { continue }
            if transaction.revocationDate == nil { owned = true }
        }
        setPro(owned)
    }

    private func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: Self.cacheKey)
    }

    /// 仅调试用：在模拟器里没有真实商品时，方便走查付费后的界面。
    #if DEBUG
    func debugTogglePro() {
        setPro(!isPro)
    }
    #endif
}