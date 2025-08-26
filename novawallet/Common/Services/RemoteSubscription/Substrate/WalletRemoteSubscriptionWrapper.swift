import Foundation
import SubstrateSdk

protocol WalletRemoteSubscriptionWrapperProtocol {
    func subscribe(
        using assetStorageInfo: AssetStorageInfo,
        accountId: AccountId,
        chainAsset: ChainAsset,
        completion: RemoteSubscriptionClosure?
    ) -> UUID?

    func unsubscribe(
        from subscriptionId: UUID,
        assetStorageInfo: AssetStorageInfo,
        accountId: AccountId,
        chainAssetId: ChainAssetId,
        completion: RemoteSubscriptionClosure?
    )
}

final class WalletRemoteSubscriptionWrapper {
    let remoteSubscriptionService: BalanceRemoteSubscriptionServiceProtocol

    init(
        remoteSubscriptionService: BalanceRemoteSubscriptionServiceProtocol
    ) {
        self.remoteSubscriptionService = remoteSubscriptionService
    }
}

extension WalletRemoteSubscriptionWrapper: WalletRemoteSubscriptionWrapperProtocol {
    func subscribe(
        using assetStorageInfo: AssetStorageInfo,
        accountId: AccountId,
        chainAsset: ChainAsset,
        completion: RemoteSubscriptionClosure?
    ) -> UUID? {
        switch assetStorageInfo {
        case .native, .statemine, .orml:
            return remoteSubscriptionService.attachToAssetBalance(
                for: accountId,
                chainAsset: chainAsset,
                queue: .main,
                closure: completion
            )
        case .erc20, .evmNative, .equilibrium, .ormlHydrationEvm:
            // not supported
            return nil
        }
    }

    func unsubscribe(
        from subscriptionId: UUID,
        assetStorageInfo: AssetStorageInfo,
        accountId: AccountId,
        chainAssetId: ChainAssetId,
        completion: RemoteSubscriptionClosure?
    ) {
        switch assetStorageInfo {
        case .native, .statemine, .orml:
            remoteSubscriptionService.detachFromAssetBalance(
                for: subscriptionId,
                accountId: accountId,
                chainAssetId: chainAssetId,
                queue: .main,
                closure: completion
            )
        case .erc20, .evmNative, .equilibrium, .ormlHydrationEvm:
            // not supported
            return
        }
    }
}
