import Foundation
import Foundation_iOS
import BigInt
import NovaCrypto

protocol StakingStateViewModelFactoryProtocol {
    func createViewModel(from state: StakingStateProtocol) -> StakingViewState
}

final class StakingStateViewModelFactory {
    let logger: LoggerProtocol?

    private var lastViewModel: StakingViewState = .undefined
    private let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    private let calendar = Calendar.current

    var balanceViewModelFactory: BalanceViewModelFactoryProtocol?
    private var cachedChainAsset: ChainAsset?

    init(
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
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

        let factory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

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

    private func createNominationViewModel(
        for chainAsset: ChainAsset,
        commonData: StakingStateCommonData,
        ledgerInfo: Staking.Ledger,
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

    private func createUnbondingViewModel(
        from stakingLedger: Staking.Ledger,
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

        return StakingUnbondingViewModel(
            eraCountdown: eraCountdown,
            items: viewModels,
            canCancelUnbonding: true
        )
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

        let alerts = stakingAlertsForBondedState(state)

        let actions: [StakingManageOption] = [
            .stakeMore,
            .unstake,
            .rewardDestination,
            .setupValidators,
            .proxyAction(from: state.commonData.proxy, chain: chainAsset.chain),
            .controllerAccount
        ].compactMap { $0 }

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

        let alerts = stakingAlertsForNominatorState(state)

        let actions: [StakingManageOption] = [
            .stakeMore,
            .unstake,
            .rewardDestination,
            .pendingRewards,
            .changeValidators(count: state.nomination.targets.count),
            .proxyAction(from: state.commonData.proxy, chain: chainAsset.chain),
            .controllerAccount
        ].compactMap { $0 }

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

        let actions: [StakingManageOption] = [
            .stakeMore,
            .unstake,
            .rewardDestination,
            .pendingRewards,
            .yourValidator,
            .proxyAction(from: state.commonData.proxy, chain: chainAsset.chain),
            .controllerAccount
        ].compactMap { $0 }

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
