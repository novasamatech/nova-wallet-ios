import Foundation
import SubstrateSdk

final class MythosStakingRemoteSubscriptionService: RemoteSubscriptionService,
    StakingRemoteSubscriptionServiceProtocol {
    private static let globalDataStoragePaths: [StorageCodingPath] = [
        MythosStakingPallet.minStakePath,
        MythosStakingPallet.currentSessionPath
    ]

    func attachToGlobalData(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        attachToGlobalDataWithStoragePaths(
            Self.globalDataStoragePaths,
            chainId: chainId,
            queue: queue,
            closure: closure
        )
    }

    func detachFromGlobalData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        detachFromGlobalDataStoragePaths(
            Self.globalDataStoragePaths,
            subscriptionId: subscriptionId,
            chainId: chainId,
            queue: queue,
            closure: closure
        )
    }
}
