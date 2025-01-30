import Foundation
import SoraFoundation

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

    private func createDelegationStatus(
        for activeStake: Balance,
        collatorStatuses: [CollatorStakingDelegationStatus]?,
        commonData _: MythosStakingCommonData
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

    private func createDelegationViewModel(
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

    private func createStakingRewardViewModel(
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

        let canClaimRewards = commonData.claimableRewards?.shouldClaim ?? false

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

    private func createLockedStateManageOptions(
        for _: MythosStakingLockedState
    ) -> [StakingManageOption] {
        [
            .stakeMore
        ]
    }

    private func createDelegatorStateManageOptions(
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
}

extension MythosStkStateViewModelFactory: MythosStakingStateVisitorProtocol {
    func visit(state _: MythosStakingInitState) {
        lastViewModel = .undefined
    }

    func visit(state _: MythosStakingDelegatorTransitionState) {
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

        // TODO: Implement in separate task
        let unbondings: StakingUnbondingViewModel? = nil

        // TODO: Implement in separate task
        let alerts: [StakingAlert] = []

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

        let delegator = CollatorStakingDelegator(mythosDelegator: state.stakingDetails)

        let electedSet = Set((state.commonData.collatorsInfo ?? []).map(\.accountId))

        let collatorsStatuses: [CollatorStakingDelegationStatus] = delegator.delegations.compactMap { delegation in
            let isElected = electedSet.contains(delegation.candidate)

            return MythosStakingCollatorDelegationState(
                delegatorModel: delegator,
                accountId: delegation.candidate,
                isElected: isElected
            ).status
        }

        let delegationStatus = createDelegationStatus(
            for: state.stakingDetails.totalStake,
            collatorStatuses: collatorsStatuses,
            commonData: state.commonData
        )

        let delegationViewModel = createDelegationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            totalStake: state.stakingDetails.totalStake,
            viewStatus: delegationStatus
        )

        // TODO: Implement in separate task
        let unbondings: StakingUnbondingViewModel? = nil

        // TODO: Implement in separate task
        let alerts: [StakingAlert] = []

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
