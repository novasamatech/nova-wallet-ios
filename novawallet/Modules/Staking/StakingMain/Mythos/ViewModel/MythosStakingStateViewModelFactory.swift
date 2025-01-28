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
        commonData: MythosStakingCommonData
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
        delegator: MythosStakingDetails,
        viewStatus: NominationViewStatus
    ) -> LocalizableResource<NominationViewModel> {
        let displayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let stakedAmount = delegator.staked.decimal(assetInfo: displayInfo)

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
        commonData: ParachainStaking.CommonData
    ) -> LocalizableResource<StakingRewardViewModel> {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        if let totalReward = commonData.totalReward {
            let localizableReward = balanceViewModelFactory.balanceFromPrice(
                totalReward.amount.decimalValue,
                priceData: commonData.price
            )

            return LocalizableResource { locale in
                let reward = localizableReward.value(for: locale)
                let filter = commonData.totalRewardFilter.map { $0.title(
                    calendar: self.calendar
                ) }?.value(for: locale)

                return StakingRewardViewModel(
                    totalRewards: .loaded(value: reward),
                    claimableRewards: nil,
                    graphics: R.image.imageStakingTypeDirect(),
                    filter: filter,
                    hasPrice: chainAsset.asset.hasPrice
                )
            }
        } else {
            return LocalizableResource { _ in
                StakingRewardViewModel(
                    totalRewards: .loading,
                    claimableRewards: nil,
                    graphics: R.image.imageStakingTypeDirect(),
                    filter: nil,
                    hasPrice: chainAsset.asset.hasPrice
                )
            }
        }
    }
    
    private func createLockedStateManageOptions(
        for state: MythosStakingLockedState
    ) -> [StakingManageOption] {
        [
            .stakeMore
        ]
    }
    
    private func createDelegatorStateManageOptions(
        for state: MythosStakingDelegatorState
    ) -> [StakingManageOption] {
        [
            .stakeMore,
            .unstake,
            .changeValidators(count: state.stakingDetails.stakeDistribution.count)
        ]
    }
}

extension MythosStkStateViewModelFactory: MythosStakingStateVisitorProtocol {
    func visit(state: MythosStakingInitState) {
        lastViewModel = .undefined
    }
    
    func visit(state: MythosStakingDelegatorTransitionState) {
        lastViewModel = .undefined
    }
    
    func visit(state: MythosStakingLockedState) {
        
    }
    
    func visit(state: MythosStakingDelegatorState) {
        let delegator = CollatorStakingDelegator(mythosDelegator: state.stakingDetails)
        
        let electedSet = Set((state.commonData.collatorsInfo ?? []).map({ $0.accountId }))
        
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
            delegator: state.stakingDetails,
            viewStatus: delegationStatus
        )

        // TODO: Implement in separate task
        let unbondings: StakingUnbondingViewModel? = nil

        // TODO: Implement in separate task
        let alerts = []

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
