import Foundation
import UIKit.UIImage

final class PurchaseAggregator {
    private var providers: [PurchaseProviderProtocol]

    init(providers: [PurchaseProviderProtocol]) {
        self.providers = providers
    }
}

extension PurchaseAggregator: PurchaseProviderProtocol {
    func with(appName: String) -> Self {
        providers = providers.map { $0.with(appName: appName) }
        return self
    }

    func with(logoUrl: URL) -> Self {
        providers = providers.map { $0.with(logoUrl: logoUrl) }
        return self
    }

    func with(colorCode: String) -> Self {
        providers = providers.map { $0.with(colorCode: colorCode) }
        return self
    }

    func with(callbackUrl: URL) -> Self {
        providers = providers.map { $0.with(callbackUrl: callbackUrl) }
        return self
    }

    func buildPurchaseActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [PurchaseAction] {
        providers.flatMap { $0.buildPurchaseActions(for: chainAsset, accountId: accountId) }
    }

    func buildRampAction(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        providers.flatMap {
            $0.buildRampAction(
                for: chainAsset,
                accountId: accountId
            )
        }
    }
}
