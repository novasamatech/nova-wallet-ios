import Foundation

extension SwapSetupPresenter {
    func showFeeInfo() {
        guard let quote, let fee else {
            return
        }

        wireframe.showFeeDetails(
            from: view,
            operations: quote.metaOperations,
            fee: fee
        )
    }

    func showRateInfo() {
        wireframe.showRateInfo(
            from: view,
            commissionRate: chargesCommission ? AssetExchangeCommissionConstants.rate : nil
        )
    }

    func showRouteDetails() {
        guard let quote, let fee else {
            return
        }

        wireframe.showRouteDetails(
            from: view,
            quote: quote,
            fee: fee
        )
    }

    func provideRouteViewModel() {
        guard let quote else {
            view?.didReceiveRoute(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.routeViewModel(from: quote.metaOperations)

        view?.didReceiveRoute(viewModel: .loaded(value: viewModel))
    }

    func provideFeeViewModel() {
        guard
            let operations = quote?.metaOperations,
            let totalFeeInFiat = fee?.calculateTotalFeeInFiat(
                matching: operations,
                priceStore: priceStore
            ) else {
            view?.didReceiveNetworkFee(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.feeViewModel(
            amountInFiat: totalFeeInFiat,
            isEditable: false,
            currencyId: feeAssetPriceData?.currencyId,
            locale: selectedLocale
        )

        view?.didReceiveNetworkFee(viewModel: .loaded(value: viewModel))
    }

    func provideCommissionDisclosureViewModel() {
        let viewModel = chargesCommission
            ? viewModelFactory.commissionDisclosureViewModel(
                rate: AssetExchangeCommissionConstants.rate,
                locale: selectedLocale
            )
            : nil

        view?.didReceiveCommissionDisclosure(viewModel: viewModel)
    }

    func provideExecutionTimeViewModel() {
        guard let quote else {
            view?.didReceiveExecutionTime(viewModel: .loading)
            return
        }

        let viewModel = viewModelFactory.executionTimeViewModel(
            from: quote.totalExecutionTime(),
            locale: selectedLocale
        )

        view?.didReceiveExecutionTime(viewModel: .loaded(value: viewModel))
    }
}
