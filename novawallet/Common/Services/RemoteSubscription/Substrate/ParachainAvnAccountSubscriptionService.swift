import Foundation
import SubstrateSdk
import Operation_iOS

extension ParachainAvn {
    final class AccountSubscriptionService: RemoteSubscriptionService {
        private static let storagePaths: [StorageCodingPath] = [
            ParachainAvn.nominatorStatePath
        ]
    }
}

extension ParachainAvn.AccountSubscriptionService: StakingRemoteAccountSubscriptionServiceProtocol {
    func attachToAccountData(
        for chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        let subscriptionHandlingFactory = ParachainAvnAccountSubscribeHandlingFactory(
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
