import Foundation
import Foundation_iOS

protocol MythosStkStateViewModelFactoryProtocol {
    func createViewModel(from state: MythosStakingStateProtocol) -> StakingViewState
}

final class MythosStkStateViewModelFactory {
    private var lastViewModel: StakingViewState = .undefined
    private(set) var priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    private let calendar = Calendar.current

    init(priceAssetInfoFactory: PriceAssetInfoFactoryProtocol) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }
}

extension MythosStkStateViewModelFactory {
    func createDelegationStatus(
        for activeStake: Balance,
        collatorStatuses: [CollatorStakingDelegationStatus]?
    ) -> NominationViewStatus {
        guard let statuses = collatorStatuses else {
            return .undefined
        }

        guard activeStake > 0 else {
            return .inactive
        }

        if statuses.contains(where: { $0 == .rewarded }) {
            return .active
        } else {
            return .inactive
        }
    }

    func createDelegationViewModel(
        for chainAsset: ChainAsset,
        commonData: MythosStakingCommonData,
        totalStake: Balance,
        viewStatus: NominationViewStatus
    ) -> LocalizableResource<NominationViewModel> {
        let displayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let stakedAmount = totalStake.decimal(assetInfo: displayInfo)

        let staked = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: commonData.price
        )

        return LocalizableResource { locale in
            let stakedViewModel = staked.value(for: locale)
            let hasPrice = commonData.price != nil

            return NominationViewModel(
                totalStakedAmount: stakedViewModel.amount,
                totalStakedPrice: stakedViewModel.price ?? "",
                status: viewStatus,
                hasPrice: hasPrice
            )
        }
    }

    func createStakingRewardViewModel(
        for chainAsset: ChainAsset,
        commonData: MythosStakingCommonData
    ) -> LocalizableResource<StakingRewardViewModel> {
        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let localizedTotalRewards = commonData.totalReward.map { rewards in
            balanceViewModelFactory.balanceFromPrice(
                rewards.amount.decimalValue,
                priceData: commonData.price
            )
        }

        let localizedClaimableRewards = commonData.claimableRewards.map { claimable in
            balanceViewModelFactory.balanceFromPrice(
                claimable.total.decimal(assetInfo: assetInfo),
                priceData: commonData.price
            )
        }

        let localizedFilter = commonData.totalRewardFilter.map { $0.title(calendar: calendar) }

        let canClaimRewards = commonData.claimableRewards.map { claimable in
            claimable.total > 0
        } ?? false

        return LocalizableResource { locale in
            let totalRewards = localizedTotalRewards?.value(for: locale)
            let claimableReward = localizedClaimableRewards?.value(for: locale)
            let claimableRewardViewModel = claimableReward.map {
                StakingRewardViewModel.ClaimableRewards(balance: $0, canClaim: canClaimRewards)
            }

            let filter = localizedFilter?.value(for: locale)

            return StakingRewardViewModel(
                totalRewards: totalRewards.map { .loaded(value: $0) } ?? .loading,
                claimableRewards: claimableRewardViewModel.map { .loaded(value: $0) } ?? .loading,
                graphics: R.image.imageStakingTypePool(),
                filter: filter,
                hasPrice: chainAsset.asset.hasPrice
            )
        }
    }

    func createLockedStateManageOptions(
        for _: MythosStakingLockedState
    ) -> [StakingManageOption] {
        [
            .stakeMore
        ]
    }

    func createDelegatorStateManageOptions(
        for state: MythosStakingDelegatorState
    ) -> [StakingManageOption] {
        let collatorsCount = state.stakingDetails.stakeDistribution.count

        if collatorsCount > 0 {
            return [
                .stakeMore,
                .unstake,
                .changeValidators(count: state.stakingDetails.stakeDistribution.count)
            ]
        } else {
            return [
                .stakeMore
            ]
        }
    }

    func createUnstakingScheduleViewModel(
        for chainAsset: ChainAsset,
        releaseQueue: MythosStakingPallet.ReleaseQueue?,
        currentBlock: BlockNumber?,
        blockTime: TimeInterval?
    ) -> StakingUnbondingViewModel? {
        guard let releaseQueue else {
            return nil
        }

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let items = releaseQueue
            .sorted { $0.block < $1.block }
            .map { request in
                let unstakingDecimal = request.amount.decimal(assetInfo: assetDisplayInfo)
                let tokenAmount = balanceFactory.amountFromValue(unstakingDecimal)

                return StakingUnbondingItemViewModel(
                    amount: tokenAmount,
                    unbondingEra: request.block
                )
            }

        let countdown: EraCountdownDisplayProtocol? = if let currentBlock, let blockTime {
            BlockCountdownDisplay(activeEra: currentBlock, blockTime: blockTime)
        } else {
            nil
        }

        return StakingUnbondingViewModel(eraCountdown: countdown, items: items, canCancelUnbonding: false)
    }

    func determineCollatorsStatus(for state: MythosStakingDelegatorState) -> [CollatorStakingDelegationStatus]? {
        guard let collatorsInfo = state.commonData.collatorsInfo else {
            return nil
        }

        let delegator = CollatorStakingDelegator(mythosDelegator: state.stakingDetails)

        let electedSet = Set(collatorsInfo.map(\.accountId))

        return delegator.delegations.compactMap { delegation in
            let isElected = electedSet.contains(delegation.candidate)

            return MythosStakingCollatorDelegationState(
                delegatorModel: delegator,
                accountId: delegation.candidate,
                isElected: isElected
            ).status
        }
    }
}

extension MythosStkStateViewModelFactory: MythosStakingStateVisitorProtocol {
    func visit(state _: MythosStakingInitState) {
        lastViewModel = .undefined
    }

    func visit(state _: MythosStakingTransitionState) {
        lastViewModel = .undefined
    }

    func visit(state: MythosStakingLockedState) {
        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        let delegationViewModel = createDelegationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            totalStake: 0,
            viewStatus: .inactive
        )

        let unbondings: StakingUnbondingViewModel? = createUnstakingScheduleViewModel(
            for: chainAsset,
            releaseQueue: state.commonData.releaseQueue,
            currentBlock: state.commonData.blockNumber,
            blockTime: state.commonData.duration?.block
        )

        let alerts: [StakingAlert] = createAlerts(
            for: nil,
            releaseQueue: state.commonData.releaseQueue,
            commonData: state.commonData
        )

        let reward = createStakingRewardViewModel(for: chainAsset, commonData: state.commonData)

        let actions = createLockedStateManageOptions(for: state)

        lastViewModel = .nominator(
            viewModel: delegationViewModel,
            alerts: alerts,
            reward: reward,
            unbondings: unbondings,
            actions: actions
        )
    }

    func visit(state: MythosStakingDelegatorState) {
        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        let collatorsStatuses = determineCollatorsStatus(for: state)

        let delegationStatus = createDelegationStatus(
            for: state.stakingDetails.totalStake,
            collatorStatuses: collatorsStatuses
        )

        let delegationViewModel = createDelegationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            totalStake: state.stakingDetails.totalStake,
            viewStatus: delegationStatus
        )

        let unbondings: StakingUnbondingViewModel? = createUnstakingScheduleViewModel(
            for: chainAsset,
            releaseQueue: state.commonData.releaseQueue,
            currentBlock: state.commonData.blockNumber,
            blockTime: state.commonData.duration?.block
        )

        let alerts: [StakingAlert] = createAlerts(
            for: collatorsStatuses,
            releaseQueue: state.commonData.releaseQueue,
            commonData: state.commonData
        )

        let reward = createStakingRewardViewModel(for: chainAsset, commonData: state.commonData)

        let actions = createDelegatorStateManageOptions(for: state)

        lastViewModel = .nominator(
            viewModel: delegationViewModel,
            alerts: alerts,
            reward: reward,
            unbondings: unbondings,
            actions: actions
        )
    }
}

extension MythosStkStateViewModelFactory: MythosStkStateViewModelFactoryProtocol {
    func createViewModel(from state: MythosStakingStateProtocol) -> StakingViewState {
        state.accept(visitor: self)
        return lastViewModel
    }
}
