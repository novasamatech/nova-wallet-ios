import Foundation
import SubstrateSdk
import Operation_iOS

extension ParachainStaking {
    final class AccountSubscriptionService: RemoteSubscriptionService {
        private static let storagePaths: [StorageCodingPath] = [
            ParachainStaking.delegatorStatePath
        ]
    }
}

extension ParachainStaking.AccountSubscriptionService: StakingRemoteAccountSubscriptionServiceProtocol {
    func attachToAccountData(
        for chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        let subscriptionHandlingFactory = ParaStkAccountSubscribeHandlingFactory(
            chainId: chainAccountId.chainId,
            accountId: chainAccountId.accountId,
            chainRegistry: chainRegistry
        )

        return attachToAccountDataWithStoragePaths(
            Self.storagePaths,
            chainAccountId: chainAccountId,
            queue: queue,
            closure: closure,
            subscriptionHandlingFactory: subscriptionHandlingFactory
        )
    }

    func detachFromAccountData(
        for subscriptionId: UUID,
        chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        detachFromAccountDataStoragePaths(
            Self.storagePaths,
            subscriptionId: subscriptionId,
            chainAccountId: chainAccountId,
            queue: queue,
            closure: closure
        )
    }
}
