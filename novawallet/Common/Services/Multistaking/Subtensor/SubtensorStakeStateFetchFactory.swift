import Foundation
import BigInt
import Operation_iOS

protocol SubtensorStakeStateFetchFactoryProtocol {
    func createStateWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<Multistaking.SubtensorStakingState>
}

enum SubtensorStakeStateFetchFactoryError: Error {
    case missingAlphaPrice(netuid: UInt16)
}

final class SubtensorStakeStateFetchFactory {
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(operationFactory: SubtensorApiOperationFactoryProtocol, operationQueue: OperationQueue) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }

    private func createPinnedStateWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash
    ) -> CompoundOperationWrapper<Multistaking.SubtensorStakingState> {
        let stakeInfoWrapper = operationFactory.createStakeInfoWrapper(for: coldkey, blockHash: blockHash)
        let pricesWrapper = operationFactory.createAlphaPricesWrapper(at: blockHash)

        let mergeOperation = ClosureOperation<Multistaking.SubtensorStakingState> {
            let stakeInfoList = try stakeInfoWrapper.targetOperation.extractNoCancellableResultData()
            let subnetPrices = try pricesWrapper.targetOperation.extractNoCancellableResultData()

            let positions = stakeInfoList.map { stakeInfo in
                SubtensorStakingPosition(
                    hotkey: stakeInfo.hotkey,
                    netuid: stakeInfo.netuid,
                    stakeAlpha: stakeInfo.stake,
                    hotkeyEmissionPerTempo: stakeInfo.emission,
                    totalHotkeyAlpha: nil,
                    isRegistered: stakeInfo.isRegistered
                )
            }

            let prices = subnetPrices.reduce(into: [UInt16: BigUInt]()) { accum, subnetPrice in
                accum[subnetPrice.netuid] = subnetPrice.price
            }

            for position in positions where position.netuid != SubtensorStakingPallet.rootNetuid {
                guard prices[position.netuid] != nil else {
                    throw SubtensorStakeStateFetchFactoryError.missingAlphaPrice(netuid: position.netuid)
                }
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

extension SubtensorStakeStateFetchFactory: SubtensorStakeStateFetchFactoryProtocol {
    func createStateWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<Multistaking.SubtensorStakingState> {
        let blockHashWrapper = operationFactory.createBestBlockHashWrapper()

        let stateWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let blockHash = try blockHashWrapper.targetOperation.extractNoCancellableResultData()

            return createPinnedStateWrapper(for: coldkey, blockHash: blockHash)
        }

        stateWrapper.addDependency(wrapper: blockHashWrapper)

        return stateWrapper.insertingHead(operations: blockHashWrapper.allOperations)
    }
}
