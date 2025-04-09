import Foundation
import UIKit.UIImage

final class RampAggregator {
    private var providers: [RampProviderProtocol]

    init(providers: [RampProviderProtocol]) {
        self.providers = providers
    }
}

extension RampAggregator: RampProviderProtocol {
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

    func buildRampActions(
        for chainAsset: ChainAsset,
        accountId: AccountId
    ) -> [RampAction] {
        providers.flatMap { $0.buildRampActions(for: chainAsset, accountId: accountId) }
    }

    func buildRampHooks(
        for action: RampAction,
        using params: OffRampHookParams,
        for delegate: RampHookDelegate
    ) -> [RampHook] {
        providers.flatMap { $0.buildRampHooks(for: action, using: params, for: delegate) }
    }
}
