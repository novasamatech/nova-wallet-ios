import Foundation
import CommonWallet
import SoraFoundation
import BigInt
import IrohaCrypto

protocol StakingStateViewModelFactoryProtocol {
    func createViewModel(from state: StakingStateProtocol) -> StakingViewState
}

typealias AnalyticsRewardsViewModelFactoryBuilder = (
    ChainAsset,
    BalanceViewModelFactoryProtocol
) -> AnalyticsRewardsViewModelFactoryProtocol

final class StakingStateViewModelFactory {
    let analyticsRewardsViewModelFactoryBuilder: AnalyticsRewardsViewModelFactoryBuilder
    let logger: LoggerProtocol?

    private var lastViewModel: StakingViewState = .undefined

    var balanceViewModelFactory: BalanceViewModelFactoryProtocol?
    private var cachedChainAsset: ChainAsset?

    init(
        analyticsRewardsViewModelFactoryBuilder: @escaping AnalyticsRewardsViewModelFactoryBuilder,
        logger: LoggerProtocol? = nil
    ) {
        self.analyticsRewardsViewModelFactoryBuilder = analyticsRewardsViewModelFactoryBuilder
        self.logger = logger
    }

    private func updateCacheForChainAsset(_ newChainAsset: ChainAsset) {
        if newChainAsset != cachedChainAsset {
            balanceViewModelFactory = nil
            cachedChainAsset = newChainAsset
        }
    }

    private func convertAmount(
        _ amount: BigUInt?,
        for chainAsset: ChainAsset,
        defaultValue: Decimal
    ) -> Decimal {
        if let amount = amount {
            return Decimal.fromSubstrateAmount(
                amount,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            ) ?? defaultValue
        } else {
            return defaultValue
        }
    }

    private func getBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        if let factory = balanceViewModelFactory {
            return factory
        }

        let factory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo)

        balanceViewModelFactory = factory

        return factory
    }

    private func createStakingRewardViewModel(
        for chainAsset: ChainAsset,
        commonData: StakingStateCommonData,
        state: BaseStashNextState
    ) -> LocalizableResource<StakingRewardViewModel> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)

        if let totalReward = state.totalReward {
            let localizableReward = balanceViewModelFactory.balanceFromPrice(
                totalReward.amount.decimalValue,
                priceData: commonData.price
            )

            return LocalizableResource { locale in
                let reward = localizableReward.value(for: locale)

                if let price = reward.price {
                    return StakingRewardViewModel(
                        amount: .loaded(reward.amount),
                        price: .loaded(price)
                    )
                } else {
                    return StakingRewardViewModel(
                        amount: .loaded(reward.amount),
                        price: nil
                    )
                }
            }
        } else {
            return LocalizableResource { _ in
                StakingRewardViewModel(amount: .loading, price: .loading)
            }
        }
    }

    private func createNominationViewModel(
        for chainAsset: ChainAsset,
        commonData: StakingStateCommonData,
        ledgerInfo: StakingLedger,
        viewStatus: NominationViewStatus
    ) -> LocalizableResource<NominationViewModel> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)

        let stakedAmount = convertAmount(ledgerInfo.active, for: chainAsset, defaultValue: 0.0)
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

    private func createValidationViewModel(
        for chainAsset: ChainAsset,
        commonData: StakingStateCommonData,
        state: ValidatorState,
        viewStatus: ValidationViewStatus
    ) -> LocalizableResource<ValidationViewModel> {
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)

        let stakedAmount = convertAmount(state.ledgerInfo.active, for: chainAsset, defaultValue: 0.0)
        let staked = balanceViewModelFactory.balanceFromPrice(
            stakedAmount,
            priceData: commonData.price
        )

        return LocalizableResource { locale in
            let stakedViewModel = staked.value(for: locale)

            return ValidationViewModel(
                totalStakedAmount: stakedViewModel.amount,
                totalStakedPrice: stakedViewModel.price ?? "",
                status: viewStatus,
                hasPrice: commonData.price != nil
            )
        }
    }

    private func createAnalyticsViewModel(
        commonData: StakingStateCommonData,
        chainAsset: ChainAsset
    ) -> LocalizableResource<RewardAnalyticsWidgetViewModel>? {
        guard let rewardsForPeriod = commonData.subqueryRewards, let rewards = rewardsForPeriod.0 else {
            return nil
        }
        let balanceViewModelFactory = getBalanceViewModelFactory(for: chainAsset)

        let analyticsViewModelFactory = analyticsRewardsViewModelFactoryBuilder(chainAsset, balanceViewModelFactory)
        let fullViewModel = analyticsViewModelFactory.createViewModel(
            from: rewards,
            priceData: commonData.price,
            period: rewardsForPeriod.1,
            selectedChartIndex: nil
        )
        return LocalizableResource { locale in
            RewardAnalyticsWidgetViewModel(
                summary: fullViewModel.value(for: locale).summaryViewModel,
                chartData: fullViewModel.value(for: locale).chartData
            )
        }
    }

    private func createEstimationViewModel(
        chainAsset: ChainAsset,
        commonData: StakingStateCommonData
    ) throws -> StakingEstimationViewModel {
        guard let calculator = commonData.calculatorEngine else {
            return StakingEstimationViewModel(tokenSymbol: chainAsset.asset.symbol, reward: nil)
        }

        let monthlyReturn = calculator.calculateMaxReturn(isCompound: true, period: .month)
        let yearlyReturn = calculator.calculateMaxReturn(isCompound: true, period: .year)

        let percentageFormatter = NumberFormatter.percentBase.localizableResource()

        let reward = LocalizableResource { locale in
            PeriodRewardViewModel(
                monthly: percentageFormatter.value(for: locale).stringFromDecimal(monthlyReturn) ?? "",
                yearly: percentageFormatter.value(for: locale).stringFromDecimal(yearlyReturn) ?? ""
            )
        }

        return StakingEstimationViewModel(
            tokenSymbol: chainAsset.asset.symbol,
            reward: reward
        )
    }

    private func createUnbondingViewModel(
        from stakingLedger: StakingLedger,
        chainAsset: ChainAsset,
        eraCountdown: EraCountdown?
    ) -> StakingUnbondingViewModel? {
        let assetPrecision = chainAsset.assetDisplayInfo.assetPrecision
        let balanceFactory = getBalanceViewModelFactory(for: chainAsset)

        let viewModels = stakingLedger
            .unlocking
            .sorted(by: { $0.era < $1.era })
            .map { unbondingItem -> StakingUnbondingItemViewModel in
                let unbondingAmountDecimal = Decimal
                    .fromSubstrateAmount(
                        unbondingItem.value,
                        precision: assetPrecision
                    ) ?? .zero
                let tokenAmount = balanceFactory.amountFromValue(unbondingAmountDecimal)

                return StakingUnbondingItemViewModel(
                    amount: tokenAmount,
                    unbondingEra: unbondingItem.era
                )
            }

        return StakingUnbondingViewModel(eraCountdown: eraCountdown, items: viewModels)
    }
}

extension StakingStateViewModelFactory: StakingStateVisitorProtocol {
    func visit(state: InitialStakingState) {
        logger?.debug("Initial state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: NoStashState) {
        logger?.debug("No stash state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        do {
            let viewModel = try createEstimationViewModel(chainAsset: chainAsset, commonData: state.commonData)

            let alerts = stakingAlertsNoStashState(state)
            lastViewModel = .noStash(viewModel: viewModel, alerts: alerts)
        } catch {
            lastViewModel = .undefined
        }
    }

    func visit(state: StashState) {
        logger?.debug("Stash state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: PendingBondedState) {
        logger?.debug("Pending bonded state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: BondedState) {
        logger?.debug("Bonded state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        let status: NominationViewStatus = .inactive

        let viewModel = createNominationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            ledgerInfo: state.ledgerInfo,
            viewStatus: status
        )

        let rewardViewModel = createStakingRewardViewModel(
            for: chainAsset,
            commonData: state.commonData,
            state: state
        )

        let analyticsViewModel = createAnalyticsViewModel(
            commonData: state.commonData,
            chainAsset: chainAsset
        )

        let alerts = stakingAlertsForBondedState(state)

        let actions: [StakingManageOption] = [
            .stakeMore,
            .unstake,
            .rewardDestination,
            .setupValidators,
            .controllerAccount
        ]

        let unbondings = state.commonData.eraCountdown.flatMap { countdown in
            createUnbondingViewModel(
                from: state.ledgerInfo,
                chainAsset: chainAsset,
                eraCountdown: countdown
            )
        }

        lastViewModel = .nominator(
            viewModel: viewModel,
            alerts: alerts,
            reward: rewardViewModel,
            analyticsViewModel: analyticsViewModel,
            unbondings: unbondings,
            actions: actions
        )
    }

    func visit(state: PendingNominatorState) {
        logger?.debug("Pending nominator state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: NominatorState) {
        logger?.debug("Nominator state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        let viewModel = createNominationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            ledgerInfo: state.ledgerInfo,
            viewStatus: state.status
        )

        let rewardViewModel = createStakingRewardViewModel(
            for: chainAsset,
            commonData: state.commonData,
            state: state
        )

        let analyticsViewModel = createAnalyticsViewModel(
            commonData: state.commonData,
            chainAsset: chainAsset
        )

        let alerts = stakingAlertsForNominatorState(state)

        let actions: [StakingManageOption] = [
            .stakeMore,
            .unstake,
            .rewardDestination,
            .pendingRewards,
            .changeValidators(count: state.nomination.targets.count),
            .controllerAccount
        ]

        let unbondings = state.commonData.eraCountdown.flatMap { countdown in
            createUnbondingViewModel(
                from: state.ledgerInfo,
                chainAsset: chainAsset,
                eraCountdown: countdown
            )
        }

        lastViewModel = .nominator(
            viewModel: viewModel,
            alerts: alerts,
            reward: rewardViewModel,
            analyticsViewModel: analyticsViewModel,
            unbondings: unbondings,
            actions: actions
        )
    }

    func visit(state: PendingValidatorState) {
        logger?.debug("Pending validator")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        lastViewModel = .undefined
    }

    func visit(state: ValidatorState) {
        logger?.debug("Validator state")

        guard let chainAsset = state.commonData.chainAsset else {
            lastViewModel = .undefined
            return
        }

        updateCacheForChainAsset(chainAsset)

        let viewModel = createValidationViewModel(
            for: chainAsset,
            commonData: state.commonData,
            state: state,
            viewStatus: state.status
        )

        let rewardViewModel = createStakingRewardViewModel(
            for: chainAsset,
            commonData: state.commonData,
            state: state
        )

        let alerts = stakingAlertsForValidatorState(state)

        let analyticsViewModel = createAnalyticsViewModel(
            commonData: state.commonData,
            chainAsset: chainAsset
        )

        let actions: [StakingManageOption] = [
            .stakeMore,
            .unstake,
            .rewardDestination,
            .pendingRewards,
            .yourValidator,
            .controllerAccount
        ]

        let unbondings = state.commonData.eraCountdown.flatMap { countdown in
            createUnbondingViewModel(
                from: state.ledgerInfo,
                chainAsset: chainAsset,
                eraCountdown: countdown
            )
        }

        lastViewModel = .validator(
            viewModel: viewModel,
            alerts: alerts,
            reward: rewardViewModel,
            analyticsViewModel: analyticsViewModel,
            unbondings: unbondings,
            actions: actions
        )
    }
}

extension StakingStateViewModelFactory: StakingStateViewModelFactoryProtocol {
    func createViewModel(from state: StakingStateProtocol) -> StakingViewState {
        state.accept(visitor: self)
        return lastViewModel
    }
}
