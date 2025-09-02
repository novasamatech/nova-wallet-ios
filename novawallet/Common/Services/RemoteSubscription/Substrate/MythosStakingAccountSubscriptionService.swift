import Foundation
import SubstrateSdk
import Operation_iOS

final class MythosStakingAccountSubscriptionService: RemoteSubscriptionService {
    private static let storagePaths: [StorageCodingPath] = [
        MythosStakingPallet.releaseQueuesPath,
        MythosStakingPallet.autoCompoundPath
    ]
}

extension MythosStakingAccountSubscriptionService: StakingRemoteAccountSubscriptionServiceProtocol {
    func attachToAccountData(
        for chainAccountId: ChainAccountId,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        attachToAccountDataWithStoragePaths(
            Self.storagePaths,
            chainAccountId: chainAccountId,
            queue: queue,
            closure: closure,
            subscriptionHandlingFactory: nil
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
