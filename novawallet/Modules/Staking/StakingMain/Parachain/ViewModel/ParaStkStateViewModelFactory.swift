import Foundation
import Foundation_iOS
import BigInt

protocol ParaStkStateViewModelFactoryProtocol {
    func createViewModel(from state: ParaStkStateProtocol) -> StakingViewState
}

final class ParaStkStateViewModelFactory {
    private var lastViewModel: StakingViewState = .undefined
    private(set) var priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    private let calendar = Calendar.current

    init(priceAssetInfoFactory: PriceAssetInfoFactoryProtocol) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }

    private func createDelegationStatus(
        for activeStake: BigUInt,
        collatorStatuses: [CollatorStakingDelegationStatus]?,
        commonData: ParachainStaking.CommonData
    ) -> NominationViewStatus {
        guard let statuses = collatorStatuses, let roundInfo = commonData.roundInfo else {
            return .undefined
        }

        guard activeStake > 0 else {
            return .inactive
        }

        if statuses.contains(where: { $0 == .rewarded }) {
            return .active
        } else if statuses.contains(where: { $0 == .pending }) {
            return .waiting(
                eraCountdown: commonData.roundCountdown,
                nominationEra: roundInfo.current
            )
        } else {
            return .inactive
        }
    }

    private func createDelegationViewModel(
        for chainAsset: ChainAsset,
        commonData: ParachainStaking.CommonData,
        delegator: ParachainStaking.Delegator,
        viewStatus: NominationViewStatus
    ) -> LocalizableResource<NominationViewModel> {
        let displayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let stakedAmount = Decimal.fromSubstrateAmount(
            delegator.staked,
            precision: displayInfo.assetPrecision
        ) ?? 0.0

        let staked = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: commonData.price
        )

        return LocalizableResource { locale in
            let stakedViewModel = staked.value(for: locale)

            return NominationViewModel(
                totalStakedAmount: stakedViewModel.amount,
                totalStakedPrice: stakedViewModel.price ?? "",
                status: viewStatus,
                hasPrice: commonData.price != nil
            )
        }
    }

    private func createUnstakingViewModel(
        from requests: [ParachainStaking.DelegatorScheduledRequest],
        chainAsset: ChainAsset,
        roundCountdown: RoundCountdown?,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) -> StakingUnbondingViewModel {
        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModels = requests
            .sorted(by: { $0.whenExecutable < $1.whenExecutable })
            .map { unstakingItem -> StakingUnbondingItemViewModel in
                let unbondingAmountDecimal = Decimal
                    .fromSubstrateAmount(
                        unstakingItem.unstakingAmount,
                        precision: assetDisplayInfo.assetPrecision
                    ) ?? .zero
                let tokenAmount = balanceFactory.amountFromValue(unbondingAmountDecimal)

                return StakingUnbondingItemViewModel(
                    amount: tokenAmount,
                    unbondingEra: unstakingItem.whenExecutable
                )
            }

        return StakingUnbondingViewModel(
            eraCountdown: roundCountdown,
            items: viewModels,
            canCancelUnbonding: true
        )
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

    private func createYieldBoostManageOption(
        from state: ParaStkYieldBoostState?,
        delegator: ParachainStaking.Delegator,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]
    ) -> StakingManageOption? {
        switch state {
        case let .supported(tasks):
            let allCollators = Set(delegator.collators())
            let disabledCollators = scheduledRequests.filter { $0.isRevoke }.map(\.collatorId)

            if allCollators == Set(disabledCollators) {
                return nil
            }

            let enabled = !tasks.isEmpty
            return .yieldBoost(enabled: enabled)
        case .none, .unsupported:
            return nil
        }
    }

    private func createDelegatorStateManageOptions(
        for state: ParachainStaking.DelegatorState
    ) -> [StakingManageOption] {
        let actions: [StakingManageOption] = [
            .stakeMore,
            .unstake,
            .changeValidators(count: state.delegatorState.delegations.count)
        ]

        if let yieldBoostOption = createYieldBoostManageOption(
            from: state.commonData.yieldBoostState,
            delegator: state.delegatorState,
            scheduledRequests: state.scheduledRequests ?? []
        ) {
            return [yieldBoostOption] + actions
        } else {
            return actions
        }
    }
}

extension ParaStkStateViewModelFactory: ParaStkStateVisitorProtocol {
    func visit(state _: ParachainStaking.InitState) {
        lastViewModel = .undefined
    }

    func visit(state: ParachainStaking.DelegatorState) {
        guard
            let chainAsset = state.commonData.chainAsset,
            let accountId = state.commonData.account?.chainAccount.accountId else {
            lastViewModel = .undefined
            return
        }

        let delegationsDict = state.delegatorState.delegationsDict()
        let delegatorModel = CollatorStakingDelegator(
            parachainDelegator: state.delegatorState
        )

        let collatorsStatuses: [CollatorStakingDelegationStatus]? = state.delegations?.compactMap { delegation in
            guard let stake = delegationsDict[delegation.accountId]?.amount else {
                return nil
            }

            return delegation.status(
                for: accountId,
                delegatorModel: delegatorModel,
                stake: stake
            )
        }

        let delegationStatus = createDelegationStatus(
            for: state.delegatorState.staked,
            collatorStatuses: collatorsStatuses,
            commonData: state.commonData
        )

        let delegationViewModel = createDelegationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            delegator: state.delegatorState,
            viewStatus: delegationStatus
        )

        let roundCountdown = state.commonData.roundCountdown
        let unbondings: StakingUnbondingViewModel? = state.scheduledRequests.map {
            createUnstakingViewModel(
                from: $0,
                chainAsset: chainAsset,
                roundCountdown: roundCountdown,
                priceAssetInfoFactory: priceAssetInfoFactory
            )
        }

        let alerts = createAlerts(
            for: collatorsStatuses,
            scheduledRequests: state.scheduledRequests,
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

extension ParaStkStateViewModelFactory: ParaStkStateViewModelFactoryProtocol {
    func createViewModel(from state: ParaStkStateProtocol) -> StakingViewState {
        state.accept(visitor: self)
        return lastViewModel
    }
}
