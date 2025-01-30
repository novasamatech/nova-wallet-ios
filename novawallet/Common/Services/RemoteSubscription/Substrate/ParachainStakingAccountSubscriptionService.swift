import Foundation
import SubstrateSdk
import Operation_iOS

protocol ParachainStakingAccountSubscriptionServiceProtocol {
    func attachToAccountData(
        for chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromAccountData(
        for subscriptionId: UUID,
        chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

extension ParachainStaking {
    final class AccountSubscriptionService: RemoteSubscriptionService,
        ParachainStakingAccountSubscriptionServiceProtocol {
        private static let storagePaths: [StorageCodingPath] = [
            ParachainStaking.delegatorStatePath
        ]

        func attachToAccountData(
            for chainAccountId: ChainAccountId,
            queue: DispatchQueue?,
            closure: RemoteSubscriptionClosure?
        ) -> UUID? {
            attachToAccountDataWithStoragePaths(
                Self.storagePaths,
                chainAccountId: chainAccountId,
                queue: queue,
                closure: closure
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
}
