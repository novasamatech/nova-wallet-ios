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
        subnetPrices: [SubtensorStakingPallet.SubnetPrice],
        availabilityList: [SubtensorStakingPallet.ColdkeyStakeAvailability],
        claimPreviews: [SubtensorStakingPallet.BasketClaimPreview]?
    ) -> Multistaking.SubtensorStakingState {
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

        let unpricedNetuids = positions.reduce(into: Set<UInt16>()) { accum, position in
            guard position.netuid != SubtensorStakingPallet.rootNetuid else {
                return
            }

            if (prices[position.netuid] ?? .zero) == .zero {
                accum.insert(position.netuid)
            }
        }

        let availability = (availabilityList.first { $0.coldkey == coldkey }?.subnets ?? []).reduce(
            into: [UInt16: SubtensorStakingPallet.StakeAvailability]()
        ) { accum, subnet in
            accum[subnet.netuid] = subnet.availability
        }

        let rootRedeemable = (claimPreviews ?? []).reduce(into: [AccountId: BigUInt]()) { accum, preview in
            guard preview.redeemableTao > 0 else {
                return
            }

            accum[preview.hotkey, default: .zero] += preview.redeemableTao
        }

        return Multistaking.SubtensorStakingState(
            positions: positions,
            prices: prices,
            availability: availability,
            unpricedNetuids: unpricedNetuids,
            rootRedeemable: rootRedeemable,
            isRootRedeemableStale: claimPreviews == nil
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
        let pricesWrapper = operationFactory.createAlphaPricesWrapper(at: blockHash)

        let availabilityWrapper = createAvailabilityWrapper(
            for: coldkey,
            blockHash: blockHash,
            stakeInfoWrapper: stakeInfoWrapper
        )

        let claimPreviewsWrapper = operationFactory.createRootClaimPreviewsWrapper(
            coldkey: coldkey,
            blockHash: blockHash
        )

        let mergeOperation = ClosureOperation<Multistaking.SubtensorStakingState> {
            try Self.createState(
                coldkey: coldkey,
                stakeInfoList: stakeInfoWrapper.targetOperation.extractNoCancellableResultData(),
                subnetPrices: pricesWrapper.targetOperation.extractNoCancellableResultData(),
                availabilityList: availabilityWrapper.targetOperation.extractNoCancellableResultData(),
                claimPreviews: try? claimPreviewsWrapper.targetOperation.extractNoCancellableResultData()
            )
        }

        mergeOperation.addDependency(stakeInfoWrapper.targetOperation)
        mergeOperation.addDependency(pricesWrapper.targetOperation)
        mergeOperation.addDependency(availabilityWrapper.targetOperation)
        mergeOperation.addDependency(claimPreviewsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: stakeInfoWrapper.allOperations + pricesWrapper.allOperations +
                availabilityWrapper.allOperations + claimPreviewsWrapper.allOperations
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
