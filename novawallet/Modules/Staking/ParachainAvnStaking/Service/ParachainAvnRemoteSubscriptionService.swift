import Foundation
import SubstrateSdk

/// Remote subscription service for Energy Web X staking.
///
/// Subscribes to the EWX-specific storage paths: `Era` (not `Round`),
/// `DefaultCollatorCommission` (not `CollatorCommission`), and
/// `TotalIssuance`. EWX does not have `InflationConfig`,
/// `InflationDistributionInfo`, or `ParachainBondInfo`, so those are
/// omitted from the subscription.
extension ParachainAvn {
    final class StakingRemoteSubscriptionService: RemoteSubscriptionService,
        StakingRemoteSubscriptionServiceProtocol {
        private static let globalDataStoragePaths: [StorageCodingPath] = [
            ParachainAvn.eraPath,
            ParachainAvn.defaultCollatorCommissionPath,
            StorageCodingPath.totalIssuance
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
