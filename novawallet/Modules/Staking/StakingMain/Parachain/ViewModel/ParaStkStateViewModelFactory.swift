import Foundation
import SoraFoundation

protocol ParaStkStateViewModelFactoryProtocol {
    func createViewModel(from state: ParaStkStateProtocol) -> StakingViewState
}

final class ParaStkStateViewModelFactory {
    private var lastViewModel: StakingViewState = .undefined

    private func createDelegationStatus(
        for response: ParachainStaking.DelegatorCollatorsResponse?,
        delegator: ParachainStaking.Delegator,
        commonData: ParachainStaking.CommonData
    ) -> NominationViewStatus {
        guard
            let response = response,
            let roundInfo = commonData.roundInfo else {
            return .undefined
        }

        let state = ParachainStaking.DelegatorRoundState(
            response: response,
            delegator: delegator
        )

        switch state {
        case .inactive:
            return .inactive
        case .active:
            return .active
        case .waiting:
            return .waiting(
                eraCountdown: commonData.roundCountdown,
                nominationEra: roundInfo.current + 1
            )
        }
    }

    private func createEstimationViewModel(
        chainAsset: ChainAsset,
        commonData: ParachainStaking.CommonData
    ) throws -> StakingEstimationViewModel {
        guard let calculator = commonData.calculatorEngine else {
            return StakingEstimationViewModel(tokenSymbol: chainAsset.asset.symbol, reward: nil)
        }

        let monthlyReturn = calculator.calculateMaxReturn(for: .month)
        let yearlyReturn = calculator.calculateMaxReturn(for: .year)

        let percentageFormatter = NumberFormatter.percentBase.localizableResource()

        let reward = LocalizableResource { locale in
            PeriodRewardViewModel(
                monthly: percentageFormatter.value(for: locale).stringFromDecimal(monthlyReturn) ?? "",
                yearly: percentageFormatter.value(for: locale).stringFromDecimal(yearlyReturn) ?? ""
            )
        }

        return StakingEstimationViewModel(tokenSymbol: chainAsset.asset.symbol, reward: reward)
    }

    private func createDelegationViewModel(
        for chainAsset: ChainAsset,
        commonData: ParachainStaking.CommonData,
        delegator: ParachainStaking.Delegator,
        viewStatus: NominationViewStatus
    ) -> LocalizableResource<NominationViewModel> {
        let displayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: displayInfo)

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
        roundCountdown: RoundCountdown?
    ) -> StakingUnbondingViewModel {
        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceFactory = BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo)

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

        return StakingUnbondingViewModel(eraCountdown: roundCountdown, items: viewModels)
    }
}

extension ParaStkStateViewModelFactory: ParaStkStateVisitorProtocol {
    func visit(state _: ParachainStaking.InitState) {
        lastViewModel = .undefined
    }

    func visit(state: ParachainStaking.NoStakingState) {
        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        guard let rewardViewModel = try? createEstimationViewModel(
            chainAsset: chainAsset,
            commonData: state.commonData
        ) else {
            lastViewModel = .undefined
            return
        }

        lastViewModel = .noStash(viewModel: rewardViewModel, alerts: [])
    }

    func visit(state: ParachainStaking.DelegatorState) {
        guard
            let chainAsset = state.commonData.chainAsset,
            let accountId = state.commonData.account?.chainAccount.accountId else {
            lastViewModel = .undefined
            return
        }

        let collatorsResponse: ParachainStaking.DelegatorCollatorsResponse?
        collatorsResponse = state.commonData.collatorsInfo.flatMap { info in
            guard let maxRewardableCollators = state.commonData.networkInfo?.maxRewardableDelegators else {
                return nil
            }

            return info.fetchRoundState(
                for: state.delegatorState,
                accountId: accountId,
                maxRewardableDelegators: maxRewardableCollators
            )
        }

        let delegationStatus = createDelegationStatus(
            for: collatorsResponse,
            delegator: state.delegatorState,
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
            createUnstakingViewModel(from: $0, chainAsset: chainAsset, roundCountdown: roundCountdown)
        }

        let alerts = createAlerts(
            for: collatorsResponse,
            delegator: state.delegatorState,
            scheduledRequests: state.scheduledRequests,
            commonData: state.commonData
        )

        lastViewModel = .nominator(
            viewModel: delegationViewModel,
            alerts: alerts,
            reward: nil,
            analyticsViewModel: nil,
            unbondings: unbondings,
            actions: [
                .stakeMore,
                .unstake,
                .changeValidators(count: state.delegatorState.delegations.count)
            ]
        )
    }
}

extension ParaStkStateViewModelFactory: ParaStkStateViewModelFactoryProtocol {
    func createViewModel(from state: ParaStkStateProtocol) -> StakingViewState {
        state.accept(visitor: self)
        return lastViewModel
    }
}
