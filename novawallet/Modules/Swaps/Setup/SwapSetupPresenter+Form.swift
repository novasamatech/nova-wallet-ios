import Foundation
import Foundation_iOS

extension SwapSetupPresenter {
    func provideFormViewModels() {
        provideSlippageViewModel()
        provideQuoteState()
    }

    func provideQuoteState() {
        let state = SwapSetupQuoteState(quoteArgs: getQuoteArgs(), quoteResult: quoteResult)
        view?.didReceive(quoteState: state)
        provideButtonState()
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
    }

    func presentQuoteFailureIfNeeded(for error: SwapBaseError) {
        guard
            case let .quote(quoteError, args) = error,
            shouldHandleRoute(for: args),
            !SwapSetupQuoteState.isNoRoute(quoteError) else {
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
