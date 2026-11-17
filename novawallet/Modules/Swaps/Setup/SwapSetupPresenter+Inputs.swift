import Foundation

extension SwapSetupPresenter {
    func getPayAmount(for input: AmountInputResult?) -> Decimal? {
        guard let input = input else {
            return nil
        }

        let maxAmount = getMaxModel().calculate()
        return input.absoluteValue(from: maxAmount)
    }

    func providePayTitle() {
        let payTitleViewModel = if let payChainAsset = getPayChainAsset(), payAssetBalance != nil {
            viewModelFactory.payTitleViewModel(
                assetDisplayInfo: payChainAsset.assetDisplayInfo,
                maxValue: getMaxModel().calculate(),
                locale: selectedLocale
            )
        } else {
            viewModelFactory.payTitleViewModel(
                assetDisplayInfo: nil,
                maxValue: nil,
                locale: selectedLocale
            )
        }

        view?.didReceiveTitle(payViewModel: payTitleViewModel)
    }

    func providePayAmountInputViewModel() {
        guard let payChainAsset = getPayChainAsset() else {
            return
        }

        let amountInputViewModel = viewModelFactory.amountInputViewModel(
            chainAsset: payChainAsset,
            amount: getPayAmount(for: payAmountInput),
            locale: selectedLocale
        )

        view?.didReceiveAmount(payInputViewModel: amountInputViewModel)
    }

    func providePayInputPriceViewModel() {
        guard let assetDisplayInfo = getPayChainAsset()?.assetDisplayInfo else {
            view?.didReceiveAmountInputPrice(payViewModel: nil)
            return
        }

        let inputPriceViewModel = viewModelFactory.inputPriceViewModel(
            assetDisplayInfo: assetDisplayInfo,
            amount: getPayAmount(for: payAmountInput),
            priceData: payAssetPriceData,
            locale: selectedLocale
        )

        view?.didReceiveAmountInputPrice(payViewModel: inputPriceViewModel)
    }

    func provideReceiveTitle() {
        let receiveTitleViewModel = viewModelFactory.receiveTitleViewModel(
            assetDisplayInfo: getReceiveChainAsset()?.assetDisplayInfo,
            balance: receiveAssetBalance?.transferable,
            locale: selectedLocale
        )

        view?.didReceiveTitle(receiveViewModel: receiveTitleViewModel)
    }

    func provideReceiveAmountInputViewModel() {
        guard let receiveChainAsset = getReceiveChainAsset() else {
            return
        }

        let amountInputViewModel = viewModelFactory.amountInputViewModel(
            chainAsset: receiveChainAsset,
            amount: receiveAmountInput,
            locale: selectedLocale
        )

        view?.didReceiveAmount(receiveInputViewModel: amountInputViewModel)
    }

    func provideReceiveInputPriceViewModel() {
        guard let assetDisplayInfo = getReceiveChainAsset()?.assetDisplayInfo else {
            view?.didReceiveAmountInputPrice(receiveViewModel: nil)
            return
        }

        let inputPriceViewModel = viewModelFactory.inputPriceViewModel(
            assetDisplayInfo: assetDisplayInfo,
            amount: receiveAmountInput,
            priceData: receiveAssetPriceData,
            locale: selectedLocale
        )

        let differenceViewModel: DifferenceViewModel?
        if let quote, let payAssetDisplayInfo = getPayChainAsset()?.assetDisplayInfo {
            let params = RateParams(
                assetDisplayInfoIn: payAssetDisplayInfo,
                assetDisplayInfoOut: assetDisplayInfo,
                amountIn: quote.route.amountIn,
                amountOut: grossAmountOut
            )

            differenceViewModel = viewModelFactory.priceDifferenceViewModel(
                rateParams: params,
                priceIn: payAssetPriceData,
                priceOut: receiveAssetPriceData,
                locale: selectedLocale
            )
        } else {
            differenceViewModel = nil
        }

        view?.didReceiveAmountInputPrice(receiveViewModel: .init(
            price: inputPriceViewModel,
            difference: differenceViewModel
        ))
    }

    func providePayAssetViews() {
        providePayTitle()
        providePayAssetViewModel()
        providePayInputPriceViewModel()
        providePayAmountInputViewModel()
    }

    func provideReceiveAssetViews() {
        provideReceiveTitle()
        provideReceiveAssetViewModel()
        provideReceiveInputPriceViewModel()
        provideReceiveAmountInputViewModel()
    }
}

// MARK: Private

private extension SwapSetupPresenter {
    func providePayAssetViewModel() {
        let payAssetViewModel = viewModelFactory.payAssetViewModel(
            chainAsset: getPayChainAsset(),
            locale: selectedLocale
        )

        view?.didReceiveInputChainAsset(payViewModel: payAssetViewModel)
    }

    func provideReceiveAssetViewModel() {
        let receiveAssetViewModel = viewModelFactory.receiveAssetViewModel(
            chainAsset: getReceiveChainAsset(),
            locale: selectedLocale
        )

        view?.didReceiveInputChainAsset(receiveViewModel: receiveAssetViewModel)
    }
}
