import Foundation
import BigInt
import Operation_iOS

protocol SubtensorStakeStateFetchFactoryProtocol {
    func createStateWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<Multistaking.SubtensorStakingState>
}

final class SubtensorStakeStateFetchFactory {
    let operationFactory: SubtensorApiOperationFactoryProtocol

    init(operationFactory: SubtensorApiOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }
}

extension SubtensorStakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol {
    func createStateWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<Multistaking.SubtensorStakingState> {
        let stakeInfoWrapper = operationFactory.createStakeInfoWrapper(for: coldkey, blockHash: nil)
        let pricesWrapper = operationFactory.createAlphaPricesWrapper(at: nil)

        let mergeOperation = ClosureOperation<Multistaking.SubtensorStakingState> {
            let stakeInfoList = try stakeInfoWrapper.targetOperation.extractNoCancellableResultData()
            let subnetPrices = try pricesWrapper.targetOperation.extractNoCancellableResultData()

            let positions = stakeInfoList.map { stakeInfo in
                SubtensorStakingPosition(
                    hotkey: stakeInfo.hotkey,
                    netuid: stakeInfo.netuid,
                    stakeAlpha: stakeInfo.stake,
                    emissionPerTempo: stakeInfo.emission,
                    isRegistered: stakeInfo.isRegistered
                )
            }

            let prices = subnetPrices.reduce(into: [UInt16: BigUInt]()) { accum, subnetPrice in
                accum[subnetPrice.netuid] = subnetPrice.price
            }

            return Multistaking.SubtensorStakingState(positions: positions, prices: prices)
        }

        mergeOperation.addDependency(stakeInfoWrapper.targetOperation)
        mergeOperation.addDependency(pricesWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: stakeInfoWrapper.allOperations + pricesWrapper.allOperations
        )
    }
}
