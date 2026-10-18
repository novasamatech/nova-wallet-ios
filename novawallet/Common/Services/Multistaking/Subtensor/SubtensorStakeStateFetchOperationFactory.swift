import Foundation
import Operation_iOS

protocol SubtensorStakeStateFetchOperationFactoryProtocol {
    func createStateWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<Multistaking.SubtensorState>
}

final class SubtensorStakeStateFetchOperationFactory {
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(operationFactory: SubtensorApiOperationFactoryProtocol, operationQueue: OperationQueue) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }

    private static func heldNetuids(of stakeInfoList: [SubtensorPallet.StakeInfo]) -> [UInt16] {
        Array(Set(stakeInfoList.map(\.netuid))).sorted()
    }

    private static func createState(
        coldkey: AccountId,
        stakeInfoList: [SubtensorPallet.StakeInfo],
        availabilityList: [SubtensorPallet.ColdkeyStakeAvailability],
        claimPreviews: [SubtensorPallet.BasketClaimPreview]?,
        minimumClaim: Balance?
    ) -> Multistaking.SubtensorState {
        let positions = stakeInfoList.map { stakeInfo in
            SubtensorPosition(
                hotkey: stakeInfo.hotkey,
                netuid: stakeInfo.netuid,
                stakeAlpha: stakeInfo.stake,
                isRegistered: stakeInfo.isRegistered
            )
        }

        let availability = (availabilityList.first { $0.coldkey == coldkey }?.subnets ?? []).reduce(
            into: [UInt16: SubtensorPallet.StakeAvailability]()
        ) { accum, subnet in
            accum[subnet.netuid] = subnet.availability
        }

        let rootClaimPreviews = minimumClaim.flatMap { minimumClaim in
            claimPreviews?.map { preview in
                SubtensorRootClaimPreview(
                    hotkey: preview.hotkey,
                    redeemable: preview.redeemableTao,
                    forfeitedEstimate: preview.forfeitedTaoEst,
                    minimumClaim: minimumClaim
                )
            }
        }

        return Multistaking.SubtensorState(
            positions: positions,
            availability: availability,
            rootClaimPreviews: rootClaimPreviews ?? [],
            isRootRedeemableStale: rootClaimPreviews == nil
        )
    }

    private func createAvailabilityWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash,
        stakeInfoWrapper: CompoundOperationWrapper<[SubtensorPallet.StakeInfo]>
    ) -> CompoundOperationWrapper<[SubtensorPallet.ColdkeyStakeAvailability]> {
        typealias Availability = [SubtensorPallet.ColdkeyStakeAvailability]

        let availabilityWrapper = OperationCombiningService<Availability>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let stakeInfoList = try stakeInfoWrapper.targetOperation.extractNoCancellableResultData()
            let netuids = Self.heldNetuids(of: stakeInfoList)

            guard !netuids.isEmpty else {
                return .createWithResult([])
            }

            return operationFactory.createStakeAvailabilityWrapper(
                for: [coldkey],
                netuids: netuids,
                blockHash: blockHash
            )
        }

        availabilityWrapper.addDependency(wrapper: stakeInfoWrapper)

        return availabilityWrapper
    }

    private func createPinnedStateWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash
    ) -> CompoundOperationWrapper<Multistaking.SubtensorState> {
        let stakeInfoWrapper = operationFactory.createStakeInfoWrapper(for: coldkey, blockHash: blockHash)

        let availabilityWrapper = createAvailabilityWrapper(
            for: coldkey,
            blockHash: blockHash,
            stakeInfoWrapper: stakeInfoWrapper
        )

        let claimPreviewsWrapper = operationFactory.createRootClaimPreviewsWrapper(
            coldkey: coldkey,
            blockHash: blockHash
        )

        let thresholdWrapper = operationFactory.createRootClaimableThresholdWrapper(blockHash: blockHash)

        let mergeOperation = ClosureOperation<Multistaking.SubtensorState> {
            try Self.createState(
                coldkey: coldkey,
                stakeInfoList: stakeInfoWrapper.targetOperation.extractNoCancellableResultData(),
                availabilityList: availabilityWrapper.targetOperation.extractNoCancellableResultData(),
                claimPreviews: try? claimPreviewsWrapper.targetOperation.extractNoCancellableResultData(),
                minimumClaim: try? SubtensorRootClaimRule.minimumClaim(
                    fromThresholdBits: thresholdWrapper.targetOperation.extractNoCancellableResultData()?.bits
                )
            )
        }

        mergeOperation.addDependency(stakeInfoWrapper.targetOperation)
        mergeOperation.addDependency(availabilityWrapper.targetOperation)
        mergeOperation.addDependency(claimPreviewsWrapper.targetOperation)
        mergeOperation.addDependency(thresholdWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: stakeInfoWrapper.allOperations + availabilityWrapper.allOperations +
                claimPreviewsWrapper.allOperations + thresholdWrapper.allOperations
        )
    }
}

extension SubtensorStakeStateFetchOperationFactory: SubtensorStakeStateFetchOperationFactoryProtocol {
    func createStateWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<Multistaking.SubtensorState> {
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
