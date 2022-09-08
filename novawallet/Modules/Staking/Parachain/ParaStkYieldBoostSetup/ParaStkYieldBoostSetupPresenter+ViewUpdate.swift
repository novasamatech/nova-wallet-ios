import Foundation

extension ParaStkYieldBoostSetupPresenter {
    func provideCollatorViewModel() {
        if
            let selectedCollator = selectedCollator,
            let address = try? selectedCollator.toAddress(using: chainAsset.chain.chainFormat) {
            let collatorDisplayAddress = DisplayAddress(
                address: address,
                username: delegationIdentities?[selectedCollator]?.name ?? ""
            )

            let collatorViewModel = accountDetailsViewModelFactory.createCollator(
                from: collatorDisplayAddress,
                delegator: delegator,
                locale: selectedLocale
            )

            view?.didReceiveCollator(viewModel: collatorViewModel)
        } else {
            view?.didReceiveCollator(viewModel: nil)
        }
    }

    func provideRewardsOptionComparisonViewModel() {
        guard let activeStake = activeCollatorDelegationInPlank(), let selectedCollator = selectedCollator else {
            view?.didReceiveRewardComparison(viewModel: .empty)
            return
        }

        let activeStakeDecimal = Decimal.fromSubstrateAmount(
            activeStake,
            precision: chainAsset.assetDisplayInfo.assetPrecision
        )

        let apr: ParaStkYieldBoostComparisonViewModel.Reward?

        if
            let rewardCalculator = rewardCalculator,
            let calculatedApr = try? rewardCalculator.calculateEarnings(
                amount: 1.0,
                collatorAccountId: selectedCollator,
                period: .year
            ) {
            apr = createRewardViewModel(from: calculatedApr, stake: activeStakeDecimal, formatter: aprFormatter)
        } else {
            apr = nil
        }

        let apy = createRewardViewModel(from: yieldBoostParams?.apy, stake: activeStakeDecimal, formatter: apyFormatter)

        let viewModel = ParaStkYieldBoostComparisonViewModel(apr: apr, apy: apy)
        view?.didReceiveRewardComparison(viewModel: viewModel)
    }

    func provideRewardOptionSelectionViewModel() {
        view?.didReceiveYieldBoostSelected(isYieldBoostSelected)
    }

    func provideYieldBoostPeriodViewModel() {
        guard let newPeriod = yieldBoostParams?.period else {
            view?.didReceiveYieldBoostPeriod(viewModel: nil)
            return
        }

        let viewModel = ParaStkYieldBoostPeriodViewModel(
            old: selectedRemoteBoostPeriod(),
            new: newPeriod
        )

        view?.didReceiveYieldBoostPeriod(viewModel: viewModel)
    }

    func provideAssetViewModel() {
        let balanceDecimal = balance.flatMap { value in
            Decimal.fromSubstrateAmount(
                value.transferable,
                precision: chainAsset.assetDisplayInfo.assetPrecision
            )
        } ?? 0

        let inputAmount = thresholdInput?.absoluteValue(from: maxSpendingAmount()) ?? 0
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            inputAmount,
            balance: balanceDecimal,
            priceData: price
        ).value(for: selectedLocale)

        view?.didReceiveAssetBalance(viewModel: viewModel)
    }

    func provideThresholdInputViewModel() {
        let inputAmount = thresholdInput?.absoluteValue(from: maxSpendingAmount()) ??
            selectedRemoteBoostThreshold()

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func updateHasChanges() {
        view?.didReceiveHasChanges(viewModel: checkChanges())
    }

    func provideYieldBoostSpecificViewModels() {
        provideYieldBoostPeriodViewModel()
        provideAssetViewModel()
        provideThresholdInputViewModel()
    }

    func provideViewModels() {
        provideCollatorViewModel()
        provideRewardsOptionComparisonViewModel()
        provideRewardOptionSelectionViewModel()

        if isYieldBoostSelected {
            provideYieldBoostSpecificViewModels()
        }

        updateHasChanges()
    }
}
