import Foundation
import Operation_iOS

protocol SubtensorRootClaimableFetching {
    func createClaimableWrapper(
        for coldkey: AccountId,
        at blockHash: BlockHash
    ) -> CompoundOperationWrapper<SubtensorRootClaimable>

    func createLatestClaimableWrapper(for coldkey: AccountId) -> CompoundOperationWrapper<SubtensorRootClaimable>
}

final class SubtensorRootClaimableFetchFactory {
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(operationFactory: SubtensorApiOperationFactoryProtocol, operationQueue: OperationQueue) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }
}

extension SubtensorRootClaimableFetchFactory: SubtensorRootClaimableFetching {
    func createClaimableWrapper(
        for coldkey: AccountId,
        at blockHash: BlockHash
    ) -> CompoundOperationWrapper<SubtensorRootClaimable> {
        let previewsWrapper = operationFactory.createRootClaimPreviewsWrapper(
            coldkey: coldkey,
            blockHash: blockHash
        )

        let mappingOperation = ClosureOperation<SubtensorRootClaimable> {
            let previews = try previewsWrapper.targetOperation.extractNoCancellableResultData()

            return SubtensorRootClaimable(
                previews: previews.map { preview in
                    SubtensorRootClaimPreview(
                        hotkey: preview.hotkey,
                        accrued: preview.accruedTao,
                        redeemable: preview.redeemableTao,
                        forfeitedEstimate: preview.forfeitedTaoEst
                    )
                }
            )
        }

        mappingOperation.addDependency(previewsWrapper.targetOperation)

        return previewsWrapper.insertingTail(operation: mappingOperation)
    }

    func createLatestClaimableWrapper(for coldkey: AccountId) -> CompoundOperationWrapper<SubtensorRootClaimable> {
        let blockHashWrapper = operationFactory.createBestBlockHashWrapper()

        let claimableWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let blockHash = try blockHashWrapper.targetOperation.extractNoCancellableResultData()

            return createClaimableWrapper(for: coldkey, at: blockHash)
        }

        claimableWrapper.addDependency(wrapper: blockHashWrapper)

        return claimableWrapper.insertingHead(operations: blockHashWrapper.allOperations)
    }
}
