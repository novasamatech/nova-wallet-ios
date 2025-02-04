import Foundation
import SubstrateSdk

extension ParachainStaking {
    final class StakingRemoteSubscriptionService: RemoteSubscriptionService,
        StakingRemoteSubscriptionServiceProtocol {
        private static let globalDataStoragePaths: [StorageCodingPath] = [
            ParachainStaking.roundPath,
            ParachainStaking.collatorCommissionPath,
            StorageCodingPath.totalIssuance,
            ParachainStaking.inflationConfigPath,

            // we can have either inflationDistributionInfoPath or parachainBondInfoPath in runtime
            ParachainStaking.inflationDistributionInfoPath,
            ParachainStaking.parachainBondInfoPath
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
                closure: closure,
                subscriptionHandlingFactory: nil
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
}
