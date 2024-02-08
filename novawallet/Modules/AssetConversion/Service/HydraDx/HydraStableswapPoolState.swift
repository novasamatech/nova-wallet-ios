import Foundation
import RobinHood
import SubstrateSdk

extension HydraStableswap {
    struct PoolRemoteState: ObservableSubscriptionStateProtocol {
        typealias TChange = PoolRemoteStateChange

        let poolInfo: HydraStableswap.PoolInfo?
        let tradability: HydraStableswap.Tradability?

        init(
            poolInfo: HydraStableswap.PoolInfo?,
            tradability: HydraStableswap.Tradability?
        ) {
            self.poolInfo = poolInfo
            self.tradability = tradability
        }

        init(change: TChange) {
            poolInfo = change.poolInfo.valueWhenDefined(else: nil)
            tradability = change.tradability.valueWhenDefined(else: nil)
        }

        func merging(change: HydraStableswap.PoolRemoteStateChange) -> HydraStableswap.PoolRemoteState {
            .init(
                poolInfo: change.poolInfo.valueWhenDefined(else: poolInfo),
                tradability: change.tradability.valueWhenDefined(else: tradability)
            )
        }
    }

    struct PoolRemoteStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case poolInfo
            case tradability
        }

        let poolInfo: UncertainStorage<HydraStableswap.PoolInfo?>
        let tradability: UncertainStorage<HydraStableswap.Tradability?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            poolInfo = try UncertainStorage(
                values: values,
                mappingKey: Key.poolInfo.rawValue,
                context: context
            )

            tradability = try UncertainStorage(
                values: values,
                mappingKey: Key.tradability.rawValue,
                context: context
            )
        }
    }
}
