import Foundation
import Operation_iOS
import SubstrateSdk

extension HydraStableswap {
    struct PoolRemoteState: ObservableSubscriptionStateProtocol {
        typealias TChange = PoolRemoteStateChange

        let poolInfo: HydraStableswap.PoolInfo?
        let tradability: HydraStableswap.Tradability?
        let pegsInfo: HydraStableswap.PoolPegInfo?
        let currentBlock: BlockNumber?

        init(
            poolInfo: HydraStableswap.PoolInfo?,
            tradability: HydraStableswap.Tradability?,
            pegsInfo: HydraStableswap.PoolPegInfo?,
            currentBlock: BlockNumber?
        ) {
            self.poolInfo = poolInfo
            self.tradability = tradability
            self.pegsInfo = pegsInfo
            self.currentBlock = currentBlock
        }

        init(change: TChange) {
            poolInfo = change.poolInfo.valueWhenDefined(else: nil)
            tradability = change.tradability.valueWhenDefined(else: nil)
            pegsInfo = change.pegsInfo.valueWhenDefined(else: nil)
            currentBlock = change.currentBlock.valueWhenDefined(else: nil)
        }

        func merging(change: HydraStableswap.PoolRemoteStateChange) -> HydraStableswap.PoolRemoteState {
            .init(
                poolInfo: change.poolInfo.valueWhenDefined(else: poolInfo),
                tradability: change.tradability.valueWhenDefined(else: tradability),
                pegsInfo: change.pegsInfo.valueWhenDefined(else: pegsInfo),
                currentBlock: change.currentBlock.valueWhenDefined(else: currentBlock)
            )
        }
    }

    struct PoolRemoteStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case poolInfo
            case tradability
            case currentBlock
            case pegsInfo
        }

        let poolInfo: UncertainStorage<HydraStableswap.PoolInfo?>
        let tradability: UncertainStorage<HydraStableswap.Tradability?>
        let pegsInfo: UncertainStorage<HydraStableswap.PoolPegInfo?>
        let currentBlock: UncertainStorage<BlockNumber?>

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

            pegsInfo = try UncertainStorage(
                values: values,
                mappingKey: Key.pegsInfo.rawValue,
                context: context
            )

            currentBlock = try UncertainStorage<StringScaleMapper<BlockNumber>?>(
                values: values,
                mappingKey: Key.currentBlock.rawValue,
                context: context
            ).map { $0?.value }
        }
    }
}
