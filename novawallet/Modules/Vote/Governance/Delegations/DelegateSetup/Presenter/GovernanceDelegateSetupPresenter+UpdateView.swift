import Foundation

extension GovernanceDelegateSetupPresenter {
    func updateAvailableBalanceView() {
        let availableInPlank = govBalanceCalculator.availableBalanceElseZero(from: assetBalance)

        let precision = chain.utilityAsset()?.displayInfo.assetPrecision ?? 0
        let balanceDecimal = Decimal.fromSubstrateAmount(
            availableInPlank,
            precision: precision
        ) ?? 0

        let viewModel = balanceViewModelFactory.balanceFromPrice(
            balanceDecimal,
            priceData: nil
        ).value(for: selectedLocale).amount

        view?.didReceiveBalance(viewModel: viewModel)
    }

    func updateChainAssetViewModel() {
        guard let asset = chain.utilityAsset() else {
            return
        }

        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let viewModel = chainAssetViewModelFactory.createViewModel(from: chainAsset)
        view?.didReceiveInputChainAsset(viewModel: viewModel)
    }

    func updateAmountPriceView() {
        if chain.utilityAsset()?.priceId != nil {
            let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee()) ?? 0

            let priceData = priceData ?? PriceData.zero()

            let price = balanceViewModelFactory.priceFromAmount(
                inputAmount,
                priceData: priceData
            ).value(for: selectedLocale)

            view?.didReceiveAmountInputPrice(viewModel: price)
        } else {
            view?.didReceiveAmountInputPrice(viewModel: nil)
        }
    }

    func provideAmountInputViewModelIfRate() {
        guard case .rate = inputResult else {
            return
        }

        provideAmountInputViewModel()
    }

    func provideAmountInputViewModel() {
        let inputAmount = inputResult?.absoluteValue(from: balanceMinusFee())

        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputAmount
        ).value(for: selectedLocale)

        view?.didReceiveAmount(inputViewModel: viewModel)
    }

    func updateLockedAmountView() {
        guard
            let lockDiff = lockDiff,
            let viewModel = lockChangeViewModelFactory.createAmountTransitionAfterDelegatingViewModel(
                from: lockDiff,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceiveLockedAmount(viewModel: viewModel)
    }

    func updateUndelegatingView() {
        guard
            let lockDiff = lockDiff,
            let blockTime = blockTime else {
            return
        }

        let viewModel = lockChangeViewModelFactory.createPeriodTransitionAfterDelegatingViewModel(
            from: lockDiff,
            blockTime: blockTime,
            locale: selectedLocale
        )

        view?.didReceiveUndelegatingPeriod(viewModel: viewModel)
    }

    func updateVotesView() {
        guard let delegation = deriveNewDelegation() else {
            return
        }

        let delegatedVotes = delegation.conviction.votes(for: delegation.balance) ?? 0

        let voteString = referendumStringsViewModelFactory.createVotes(
            from: delegatedVotes,
            chain: chain,
            locale: selectedLocale
        )

        view?.didReceiveVotes(viewModel: voteString ?? "")
    }

    func provideConviction() {
        view?.didReceiveConviction(viewModel: UInt(conviction.rawValue))
    }

    func provideReuseLocksViewModel() {
        guard let model = deriveReuseLocks() else {
            return
        }

        let governance: String?

        if model.governance > 0 {
            governance = balanceViewModelFactory.amountFromValue(model.governance).value(for: selectedLocale)
        } else {
            governance = nil
        }

        let all: String?

        if model.all > 0, model.all != model.governance {
            all = balanceViewModelFactory.amountFromValue(model.all).value(for: selectedLocale)
        } else {
            all = nil
        }

        let viewModel = ReferendumLockReuseViewModel(governance: governance, all: all)
        view?.didReceiveLockReuse(viewModel: viewModel)
    }

    func updateHintView() {
        let hint1 = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govAddDelegateHint1()
        let hint2 = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.govAddDelegateHint2()

        view?.didReceiveHints(viewModel: [hint1, hint2])
    }

    func updateView() {
        updateAvailableBalanceView()
        provideAmountInputViewModel()
        updateChainAssetViewModel()
        updateAmountPriceView()
        updateVotesView()
        updateLockedAmountView()
        updateUndelegatingView()
        provideReuseLocksViewModel()
        updateHintView()
    }
}
