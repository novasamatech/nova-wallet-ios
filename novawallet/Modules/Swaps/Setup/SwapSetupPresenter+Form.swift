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

    func provideQuoteState() {
        let state = SwapSetupQuoteState(quoteArgs: getQuoteArgs(), quoteResult: quoteResult)
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

        presentPendingQuoteFailure()
    }

    func presentPendingQuoteFailure() {
        guard
            quoteFailureAlertState == .pending,
            case let .failure(error) = quoteResult,
            SwapQuoteFailure(error: error) == .fetchFailed else {
            return
        }

        guard view?.isFrontmost == true else {
            view?.notifyWhenFrontmost()
            return
        }

        let strings = R.string(preferredLanguages: selectedLocale.rLanguages).localizable

        wireframe.presentRequestStatus(
            on: view,
            title: strings.swapsSetupChartFailedTitle(),
            message: strings.swapsSetupChartFailedMessage(),
            locale: selectedLocale,
            retryAction: { [weak self] in
                self?.retryQuote()
            },
            skipAction: {}
        )

        guard view?.isFrontmost == false else {
            view?.notifyWhenFrontmost()
            return
        }

        quoteFailureAlertState = .ended
    }

    func didBecomeFrontmost() {
        presentPendingQuoteFailure()
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
