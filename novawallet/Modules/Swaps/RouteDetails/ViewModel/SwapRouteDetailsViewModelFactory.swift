import Foundation

protocol SwapRouteDetailsViewModelFactoryProtocol {
    func createViewModel(
        for operation: AssetExchangeMetaOperationProtocol,
        fee: AssetExchangeOperationFee,
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> SwapRouteDetailsItemContent.ViewModel
}

final class SwapRouteDetailsViewModelFactory {
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    init(
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory()
    ) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
        balanceViewModelFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)
        self.assetIconViewModelFactory = assetIconViewModelFactory
    }
}

private extension SwapRouteDetailsViewModelFactory {
    func createType(
        from operation: AssetExchangeMetaOperationProtocol,
        locale: Locale
    ) -> String {
        switch operation.label {
        case .swap:
            R.string.localizable.swapsLabelSwap(preferredLanguages: locale.rLanguages)
        case .transfer:
            R.string.localizable.swapsLabelTransfer(preferredLanguages: locale.rLanguages)
        }
    }

    func createAmountItem(
        from chainAsset: ChainAsset,
        amount: Balance,
        locale: Locale
    ) -> AssetAmountRouteItemView.ViewModel {
        let assetDisplayInfo = chainAsset.assetDisplayInfo

        let imageViewModel = assetIconViewModelFactory.createAssetIconViewModel(
            from: assetDisplayInfo
        )

        let amount = balanceViewModelFacade.amountFromValue(
            targetAssetInfo: assetDisplayInfo,
            value: amount.decimal(assetInfo: assetDisplayInfo)
        ).value(for: locale)

        return AssetAmountRouteItemView.ViewModel(imageViewModel: imageViewModel, amount: amount)
    }

    func createAmountItems(
        from operation: AssetExchangeMetaOperationProtocol,
        locale: Locale
    ) -> [AssetAmountRouteItemView.ViewModel] {
        switch operation.label {
        case .swap:
            [
                createAmountItem(
                    from: operation.assetIn,
                    amount: operation.amountIn,
                    locale: locale
                ),
                createAmountItem(
                    from: operation.assetOut,
                    amount: operation.amountOut,
                    locale: locale
                )
            ]
        case .transfer:
            [
                createAmountItem(
                    from: operation.assetOut,
                    amount: operation.amountOut,
                    locale: locale
                )
            ]
        }
    }

    func createNetworkItems(from operation: AssetExchangeMetaOperationProtocol) -> [LabelRouteItemView.ViewModel] {
        switch operation.label {
        case .swap:
            [
                operation.assetIn.chain.name
            ]
        case .transfer:
            [
                operation.assetIn.chain.name,
                operation.assetOut.chain.name
            ]
        }
    }

    func createFee(
        from fee: AssetExchangeOperationFee,
        chain: ChainModel,
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> String {
        let totalAmountInFiat = fee.totalInFiat(in: chain, prices: prices)

        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(
            from: prices.first?.value.currencyId
        )

        let amount = balanceViewModelFacade.amountFromValue(
            targetAssetInfo: assetDisplayInfo,
            value: totalAmountInFiat
        ).value(for: locale)

        return R.string.localizable.commonFeeAmountPrefixed(
            amount,
            preferredLanguages: locale.rLanguages
        )
    }
}

extension SwapRouteDetailsViewModelFactory: SwapRouteDetailsViewModelFactoryProtocol {
    func createViewModel(
        for operation: AssetExchangeMetaOperationProtocol,
        fee: AssetExchangeOperationFee,
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> SwapRouteDetailsItemContent.ViewModel {
        let fee = createFee(
            from: fee,
            chain: operation.assetIn.chain,
            prices: prices,
            locale: locale
        )

        return SwapRouteDetailsItemContent.ViewModel(
            type: createType(from: operation, locale: locale),
            amountItems: createAmountItems(from: operation, locale: locale),
            fee: fee,
            networkItems: createNetworkItems(from: operation)
        )
    }
}
