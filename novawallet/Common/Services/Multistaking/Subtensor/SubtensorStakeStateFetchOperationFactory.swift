import Foundation
import Operation_iOS

protocol SubtensorStakeStateFetchOperationFactoryProtocol {
    func createStateWrapper(
        for coldkey: AccountId
    ) -> CompoundOperationWrapper<Multistaking.SubtensorStakingState>
}

final class SubtensorStakeStateFetchOperationFactory {
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(operationFactory: SubtensorApiOperationFactoryProtocol, operationQueue: OperationQueue) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }

    private static func heldNetuids(of stakeInfoList: [SubtensorStakingPallet.StakeInfo]) -> [UInt16] {
        Array(Set(stakeInfoList.map(\.netuid))).sorted()
    }

    private static func createState(
        coldkey: AccountId,
        stakeInfoList: [SubtensorStakingPallet.StakeInfo],
        availabilityList: [SubtensorStakingPallet.ColdkeyStakeAvailability],
        claimPreviews: [SubtensorStakingPallet.BasketClaimPreview]?,
        minimumClaim: Balance?
    ) -> Multistaking.SubtensorStakingState {
        let positions = stakeInfoList.map { stakeInfo in
            SubtensorStakingPosition(
                hotkey: stakeInfo.hotkey,
                netuid: stakeInfo.netuid,
                stakeAlpha: stakeInfo.stake,
                isRegistered: stakeInfo.isRegistered
            )
        }

        let availability = (availabilityList.first { $0.coldkey == coldkey }?.subnets ?? []).reduce(
            into: [UInt16: SubtensorStakingPallet.StakeAvailability]()
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

        return Multistaking.SubtensorStakingState(
            positions: positions,
            availability: availability,
            rootClaimPreviews: rootClaimPreviews ?? [],
            isRootRedeemableStale: rootClaimPreviews == nil
        )
    }

    private func createAvailabilityWrapper(
        for coldkey: AccountId,
        blockHash: BlockHash,
        stakeInfoWrapper: CompoundOperationWrapper<[SubtensorStakingPallet.StakeInfo]>
    ) -> CompoundOperationWrapper<[SubtensorStakingPallet.ColdkeyStakeAvailability]> {
        typealias Availability = [SubtensorStakingPallet.ColdkeyStakeAvailability]

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
    ) -> CompoundOperationWrapper<Multistaking.SubtensorStakingState> {
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

        let mergeOperation = ClosureOperation<Multistaking.SubtensorStakingState> {
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
