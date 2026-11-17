import Foundation

extension SwapSetupPresenter: AssetPriceChartInputOwnerProtocol {}

extension SwapSetupPresenter {
    func provideChartAsset() {
        let followedChainAsset = SwapPriceChartFollowRule.followedChainAsset(
            pay: getPayChainAsset(),
            receive: getReceiveChainAsset()
        )

        guard followedChainAsset?.chainAssetId != chartContext.followedChainAsset?.chainAssetId else {
            return
        }

        chartContext.followedChainAsset = followedChainAsset
        chartContext.state = nil
        chartContext.hasPendingFailure = false

        assetPriceChartModule?.updateAsset(followedChainAsset?.asset)

        provideChartViewModel()
    }

    func selectChartExpansion(_ isExpanded: Bool) {
        chartContext.manualExpansion = isExpanded
        interactor.saveChartExpansion(isExpanded)

        provideChartViewModel()
        presentPendingFailures()
    }

    func didChangeChartVisibility() {
        presentPendingFailures()
    }

    var isChartFailureAlertPending: Bool {
        chartContext.hasPendingFailure && view?.isChartShownExpanded == true
    }

    func didReceiveChartExpansion(_ isExpanded: Bool?) {
        chartContext.manualExpansion = isExpanded

        provideChartViewModel()
    }

    func didReceive(selectedCurrency: Currency) {
        assetPriceChartModule?.updateSelectedCurrency(selectedCurrency)
    }
}

// MARK: Private

private extension SwapSetupPresenter {
    var isChartExpandable: Bool {
        if case .unavailable(.noHistory) = chartContext.state {
            return false
        }

        return true
    }

    var isChartExpanded: Bool {
        guard isChartExpandable else {
            return false
        }

        if let manualExpansion = chartContext.manualExpansion {
            return manualExpansion
        }

        guard placement == .swapsTab, let followedChainAsset = chartContext.followedChainAsset else {
            return false
        }

        return !SwapPriceChartFollowRule.isStablecoin(followedChainAsset)
    }

    func provideChartViewModel() {
        let viewModel = SwapPriceChartViewModel(
            isExpanded: isChartExpanded,
            isExpandable: isChartExpandable
        )

        view?.didReceiveChart(viewModel: viewModel)
    }
}

// MARK: AssetPriceChartModuleOutputProtocol

extension SwapSetupPresenter: AssetPriceChartModuleOutputProtocol {
    func didReceiveChartState(_ state: AssetPriceChartState) {
        let wasFailed = chartContext.isFailed

        chartContext.state = state

        if !chartContext.isFailed {
            chartContext.hasPendingFailure = false
        } else if !wasFailed {
            chartContext.hasPendingFailure = true
        }

        provideChartViewModel()
        presentPendingFailures()
    }

    func didSelectChartPeriod(_ period: PriceHistoryPeriod) {
        interactor.saveChartPeriod(period)
    }
}
