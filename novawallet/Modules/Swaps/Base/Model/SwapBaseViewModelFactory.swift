import Foundation
import BigInt
import Foundation_iOS

struct RateParams {
    let assetDisplayInfoIn: AssetBalanceDisplayInfo
    let assetDisplayInfoOut: AssetBalanceDisplayInfo
    let amountIn: BigUInt
    let amountOut: BigUInt
}

protocol SwapBaseViewModelFactoryProtocol {
    func rateViewModel(from params: RateParams, locale: Locale) -> String

    func routeViewModel(from metaOperations: [AssetExchangeMetaOperationProtocol]) -> [SwapRouteItemView.ViewModel]

    func executionTimeViewModel(from timeInterval: TimeInterval, locale: Locale) -> String

    func priceDifferenceViewModel(
        rateParams: RateParams,
        priceIn: PriceData?,
        priceOut: PriceData?,
        locale: Locale
    ) -> DifferenceViewModel?

    func feeViewModel(
        amountInFiat: Decimal,
        isEditable: Bool,
        currencyId: Int?,
        locale: Locale
    ) -> NetworkFeeInfoViewModel
}

class SwapBaseViewModelFactory {
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    let priceDifferenceModelFactory: SwapPriceDifferenceModelFactoryProtocol
    let percentFormatter: LocalizableResource<NumberFormatter>
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        priceDifferenceModelFactory: SwapPriceDifferenceModelFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
        self.priceDifferenceModelFactory = priceDifferenceModelFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.percentFormatter = percentFormatter
    }

    func formatPriceDifference(amount: Decimal, locale: Locale) -> String {
        percentFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }
}

extension SwapBaseViewModelFactory: SwapBaseViewModelFactoryProtocol {
    func rateViewModel(from params: RateParams, locale: Locale) -> String {
        guard
            let rate = Decimal.rateFromSubstrate(
                amount1: params.amountIn,
                amount2: params.amountOut,
                precision1: params.assetDisplayInfoIn.assetPrecision,
                precision2: params.assetDisplayInfoOut.assetPrecision
            ) else {
            return ""
        }

        let amountIn = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: params.assetDisplayInfoIn,
            value: 1
        ).value(for: locale)
        let amountOut = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: params.assetDisplayInfoOut,
            value: rate
        ).value(for: locale)

        return amountIn.estimatedEqual(to: amountOut)
    }

    func priceDifferenceViewModel(
        rateParams params: RateParams,
        priceIn: PriceData?,
        priceOut: PriceData?,
        locale: Locale
    ) -> DifferenceViewModel? {
        guard
            let model = priceDifferenceModelFactory.createModel(
                params: params,
                priceIn: priceIn,
                priceOut: priceOut
            ) else {
            return nil
        }

        let diffString = formatPriceDifference(amount: model.diff, locale: locale)

        return DifferenceViewModel(details: diffString, attention: model.attention)
    }

    func routeViewModel(from metaOperations: [AssetExchangeMetaOperationProtocol]) -> [SwapRouteItemView.ViewModel] {
        let chains = metaOperations.flatMap { operation in
            [operation.assetIn.chain, operation.assetOut.chain]
        }

        var interchangingChains: [ChainModel] = []

        for chain in chains where interchangingChains.last?.chainId != chain.chainId {
            interchangingChains.append(chain)
        }

        return interchangingChains.map { chain in
            SwapRouteItemView.ItemViewModel(
                title: nil,
                icon: ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)
            )
        }
    }

    func executionTimeViewModel(from timeInterval: TimeInterval, locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.commonSecondsFormat(
            format: Int(timeInterval.rounded(.up))
        ).approximately()
    }

    func feeViewModel(
        amountInFiat: Decimal,
        isEditable: Bool,
        currencyId: Int?,
        locale: Locale
    ) -> NetworkFeeInfoViewModel {
        let amount = balanceViewModelFactoryFacade.priceFromFiatAmount(
            amountInFiat,
            currencyId: currencyId
        ).value(for: locale)

        return .init(
            isEditable: isEditable,
            balanceViewModel: BalanceViewModel(amount: amount, price: nil)
        )
    }
}
