import Foundation
import SubstrateSdk
import Operation_iOS

protocol MythosStakingAccountSubscriptionServiceProtocol {
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

final class MythosStakingAccountSubscriptionService: RemoteSubscriptionService,
    MythosStakingAccountSubscriptionServiceProtocol {
    private static let storagePaths: [StorageCodingPath] = [
        MythosStakingPallet.releaseQueuesPath
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
