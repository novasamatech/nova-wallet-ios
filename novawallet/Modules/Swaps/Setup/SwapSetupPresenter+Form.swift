import Foundation
import Foundation_iOS

extension SwapSetupPresenter {
    func provideFormViewModels() {
        provideSlippageViewModel()
        provideQuoteState()
        provideMinReceivedViewModel()
    }

    func provideMinReceivedViewModel() {
        guard let quote, let receiveChainAsset = getReceiveChainAsset() else {
            view?.didReceiveMinReceived(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.minReceivedViewModel(
            for: quote,
            slippage: slippage,
            chainAsset: receiveChainAsset,
            locale: selectedLocale
        )

        view?.didReceiveMinReceived(viewModel: .loaded(value: viewModel))
    }

    func getIssueParams() -> SwapIssueCheckParams {
        .init(
            payChainAsset: getPayChainAsset(),
            receiveChainAsset: getReceiveChainAsset(),
            payAmount: isPayAmountHidden ? nil : getSpendingInputAmount(),
            receiveAmount: isReceiveAmountHidden ? nil : receiveAmountInput,
            payAssetBalance: payAssetBalance,
            receiveAssetBalance: receiveAssetBalance,
            payAssetExistense: payAssetBalanceExistense,
            receiveAssetExistense: receiveAssetBalanceExistense,
            quoteResult: quoteResult,
            fee: fee,
            isFeePending: isFeePending && quote != nil && !isQuietMaxRequote,
            refreshOrigin: refreshOrigin,
            isPayAmountHidden: isPayAmountHidden,
            wasShowingInsufficientBalance: wasShowingInsufficientBalance,
            isAwaitingPayBalance: maxBalanceRequote.isAwaitingPayBalance
        )
    }

    func provideButtonState() {
        let buttonState = viewModelFactory.buttonState(
            for: getIssueParams(),
            locale: selectedLocale
        )

        view?.didReceiveButtonState(
            title: buttonState.title.value(for: selectedLocale),
            enabled: buttonState.enabled && !isPayAssetCollateralLimitPending
        )
    }

    func provideSettingsState() {
        view?.didReceiveSettingsState(isAvailable: getPayChainAsset() != nil)
    }

    func provideQuoteState() {
        let state: SwapSetupQuoteState = maxBalanceRequote.isAwaitingPayBalance
            ? .awaitingPayBalance
            : SwapSetupQuoteState(quoteArgs: getQuoteArgs(), quoteResult: quoteResult)
        view?.didReceive(quoteState: state)
        provideButtonState()
    }

    var isPayAmountHidden: Bool {
        getQuoteArgs()?.direction == .buy && quote == nil
    }

    var isReceiveAmountHidden: Bool {
        getQuoteArgs()?.direction == .sell && quote == nil
    }

    func updateRefreshOrigin(replacing oldQuoteResult: Result<AssetExchangeQuote, Error>?) {
        if quoteResult == nil {
            refreshOrigin = .user
            maxBalanceRequote.quietQuoteArgs = nil
        } else if oldQuoteResult != nil {
            markBackgroundRefresh()
        }
    }

    func markBackgroundRefresh() {
        guard quoteResult != nil, !(isFeePending && quote != nil) else {
            return
        }

        refreshOrigin = .background
    }

    func didReceive(price: PriceData?, priceId: AssetModel.PriceId) {
        handleNewPrice(price, priceId: priceId)
    }

    func provideSlippageViewModel() {
        let viewModel = viewModelFactory.slippageViewModel(
            slippage: slippage,
            bounds: slippageBounds,
            locale: selectedLocale
        )

        view?.didReceiveSlippage(viewModel: viewModel)
    }

    func provideInitialFocus() {
        guard placement == .flow else {
            return
        }

        if initState.direction == .buy, getReceiveChainAsset() != nil {
            view?.didReceive(focus: .receiveAsset)
        } else if getPayChainAsset() != nil {
            view?.didReceive(focus: .payAsset)
        }
    }

    func showPriceDifferenceInfo() {
        let title = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsSetupPriceDifference()
        }

        let details = LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsSetupPriceDifferenceDescription()
        }

        wireframe.showInfo(from: view, title: title, details: details)
    }

    func retryQuote() {
        refreshQuote(direction: getQuoteArgs()?.direction ?? .sell)
        armQuoteFailureAlert()
        provideIssues()
    }

    func armQuoteFailureAlert() {
        quoteFailureAlertState = .armed
    }

    func startQuoteFailureEpisodeIfNeeded(for error: SwapBaseError) {
        guard
            case let .quote(quoteError, args) = error,
            shouldHandleRoute(for: args),
            SwapQuoteFailure(error: quoteError) == .fetchFailed else {
            return
        }

        if quoteFailureAlertState == .armed {
            quoteFailureAlertState = .pending
        }

        presentPendingFailures()
    }

    var isQuoteFailureAlertPending: Bool {
        guard quoteFailureAlertState == .pending, case let .failure(error) = quoteResult else {
            return false
        }

        return SwapQuoteFailure(error: error) == .fetchFailed
    }

    func presentPendingFailures() {
        let retriesQuote = isQuoteFailureAlertPending
        let retriesChart = isChartFailureAlertPending

        guard
            retriesQuote || retriesChart,
            presentRetryAlertWhenFrontmost(retryAction: { [weak self] in
                if retriesQuote {
                    self?.retryQuote()
                }

                if retriesChart {
                    self?.assetPriceChartModule?.reload()
                }
            }) else {
            return
        }

        if retriesQuote {
            quoteFailureAlertState = .ended
        }

        if retriesChart {
            chartContext.hasPendingFailure = false
        }
    }

    func presentRetryAlertWhenFrontmost(retryAction: @escaping () -> Void) -> Bool {
        guard requireFrontmost() else {
            return false
        }

        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        wireframe.presentRequestStatus(
            on: view,
            title: strings.swapsSetupChartFailedTitle(),
            message: strings.swapsSetupChartFailedMessage(),
            locale: selectedLocale,
            retryAction: retryAction,
            skipAction: {}
        )

        guard view?.isFrontmost == false else {
            view?.notifyWhenFrontmost()
            return false
        }

        return true
    }

    func requireFrontmost() -> Bool {
        guard view?.isFrontmost == true else {
            view?.notifyWhenFrontmost()
            return false
        }

        return true
    }

    func requoteOnPoolChange() {
        maxBalanceRequote.quietQuoteArgs = nil
        markBackgroundRefresh()
        refreshQuote(direction: getQuoteArgs()?.direction ?? .sell, forceUpdate: false)
        estimateFee()
    }

    func catchUpPoolRequote() {
        guard hasPendingPoolRequote else {
            return
        }

        hasPendingPoolRequote = false

        guard getQuoteArgs() != nil else {
            return
        }

        if quoteFailureAlertState == .pending {
            armQuoteFailureAlert()
        }

        requoteOnPoolChange()
    }

    func didBecomeFrontmost() {
        catchUpMaxBalanceRequote()
        catchUpPoolRequote()
        presentPendingFailures()
    }
}

extension SwapSetupPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateViews()
            assetPriceChartModule?.updateLocale(selectedLocale)
        }
    }
}

extension SwapSetupPresenter: SwapSetupModuleInputProtocol {
    var currentPairInitState: SwapSetupInitState {
        SwapSetupInitState(payChainAsset: getPayChainAsset(), receiveChainAsset: getReceiveChainAsset())
    }
}
