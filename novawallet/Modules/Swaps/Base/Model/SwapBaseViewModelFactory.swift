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
    let percentForamatter: LocalizableResource<NumberFormatter>
    let priceDifferenceConfig: SwapPriceDifferenceConfig
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        percentForamatter: LocalizableResource<NumberFormatter>,
        priceDifferenceConfig: SwapPriceDifferenceConfig
    ) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.percentForamatter = percentForamatter
        self.priceDifferenceConfig = priceDifferenceConfig
    }

    func formatPriceDifference(amount: Decimal, locale: Locale) -> String {
        percentForamatter.value(for: locale).stringFromDecimal(amount) ?? ""
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
        guard let priceIn = priceIn?.decimalRate, let priceOut = priceOut?.decimalRate else {
            return nil
        }

        guard
            let amountOutDecimal = Decimal.fromSubstrateAmount(
                params.amountOut,
                precision: params.assetDisplayInfoOut.assetPrecision
            ),
            let amountInDecimal = Decimal.fromSubstrateAmount(
                params.amountIn,
                precision: params.assetDisplayInfoIn.assetPrecision
            ) else {
            return nil
        }

        let amountPriceIn = amountInDecimal * priceIn
        let amountPriceOut = amountOutDecimal * priceOut

        guard amountPriceIn > 0, amountPriceOut > 0, amountPriceIn > amountPriceOut else {
            return nil
        }

        let diff = abs(amountPriceIn - amountPriceOut) / amountPriceIn
        let diffString = formatPriceDifference(amount: diff, locale: locale)

        switch diff {
        case _ where diff >= priceDifferenceConfig.high:
            return .init(details: diffString, attention: .high)
        case priceDifferenceConfig.medium ... priceDifferenceConfig.high:
            return .init(details: diffString, attention: .medium)
        case priceDifferenceConfig.low ... priceDifferenceConfig.medium:
            return .init(details: diffString, attention: .low)
        default:
            return nil
        }
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
        R.string.localizable.commonSecondsFormat(
            format: Int(timeInterval.rounded(.up)),
            preferredLanguages: locale.rLanguages
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
