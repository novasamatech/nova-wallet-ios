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
    
    init(
        balanceViewModelFacade: BalanceViewModelFactoryFacadeProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory()
    ) {
        self.balanceViewModelFacade = balanceViewModelFacade
        self.assetIconViewModelFactory = assetIconViewModelFactory
    }
}

private extension SwapRouteDetailsViewModelFactory {
    func createType(
        from operation: AssetExchangeMetaOperationProtocol,
        locale: Locale
    ) -> String {
        switch self {
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
        )
        
        return AssetAmountRouteItemView.ViewModel(imageViewModel: imageViewModel, amount: amount)
    }
    
    func createAmountItems(
        from operation: AssetExchangeMetaOperationProtocol,
        locale: Locale
    ) -> [AssetAmountRouteItemView.ViewModel] {
        switch operation {
        case .swap:
            [
                createAmountItem(
                    from: operation.assetIn,
                    amount: operation.amountIn,
                    locale: locale
                ),
                [
                    createAmountItem(
                        from: operation.assetOut,
                        amount: operation.amountOut,
                        locale: locale
                    )
                ]
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
        switch operation {
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
        let amounts = fee.groupedAmountByAsset()
        
        let totalAmountInFiat = amounts
            .map { keyValue in
                guard
                    keyValue.key.chainId == chain.chainId,
                    let chainAssetInfo = chain.chainAsset(for: keyValue.key.assetId)?.assetDisplayInfo else {
                    return 0
                }
            
                return Decimal.fiatValue(
                    from: keyValue.value,
                    price: prices[keyValue.key],
                    precision: chainAssetInfo.assetPrecision
                )
            }
            .reduce(Decimal(0)) { $1 + $0 }
        
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(
            from: prices.first?.value.currencyId
        )

        let amount = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: assetDisplayInfo,
            value: totalAmountInFiat
        ).value(for: locale)
        
        return amount
    }
}

extension SwapRouteDetailsViewModelFactory: SwapRouteDetailsViewModelFactoryProtocol {
    func createViewModel(
        for operation: AssetExchangeMetaOperationProtocol,
        fee: AssetExchangeOperationFee,
        prices: [ChainAssetId: PriceData],
        locale: Locale
    ) -> SwapRouteDetailsItemContent.ViewModel {
        
        return SwapRouteDetailsItemContent.ViewModel(
            type: createType(from: operation, locale: locale),
            amountItems: createAmountItems(from: operation, locale: locale),
            fee: "",
            networkItems: createNetworkItems(from: operation)
        )
    }
}
