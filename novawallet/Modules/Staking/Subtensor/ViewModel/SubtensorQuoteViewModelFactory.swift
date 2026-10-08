import BigInt
import Foundation

struct SubtensorTradePanelViewModel {
    let receive: BalanceViewModelProtocol?
    let swapRate: String
}

protocol SubtensorQuoteViewModelFactoryProtocol {
    func createTradePanel(
        for quote: SubtensorTradeQuote?,
        amountIn: Balance?,
        direction: SubtensorTradeDirection,
        target: SubtensorStakeTarget,
        taoPrice: PriceData?,
        locale: Locale
    ) -> SubtensorTradePanelViewModel?

    func createSlippageViewModel(
        for tolerance: BigRational,
        locale: Locale
    ) -> String?

    func novaFeeDisclosure(locale: Locale) -> String
}

final class SubtensorQuoteViewModelFactory {
    let chainAsset: ChainAsset
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol

    private let formatterFactory = AssetBalanceFormatterFactory()

    init(chainAsset: ChainAsset, priceAssetInfoFactory: PriceAssetInfoFactoryProtocol) {
        self.chainAsset = chainAsset
        self.priceAssetInfoFactory = priceAssetInfoFactory
    }
}

private extension SubtensorQuoteViewModelFactory {
    func formatAmount(
        _ amount: Balance,
        displayInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        let decimal = amount.decimal(assetInfo: displayInfo)

        let formatter = formatterFactory.createTokenFormatter(for: displayInfo)

        return formatter.value(for: locale).stringFromDecimal(decimal) ?? ""
    }

    func formatFiat(taoAmount: Balance, taoPrice: PriceData?, locale: Locale) -> String? {
        guard let taoPrice else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        return balanceViewModelFactory.balanceFromPrice(
            taoAmount.decimal(assetInfo: chainAsset.assetDisplayInfo),
            priceData: taoPrice
        ).value(for: locale).price
    }

    func formatSwapRate(
        for quote: SubtensorTradeQuote,
        inInfo: AssetBalanceDisplayInfo,
        outInfo: AssetBalanceDisplayInfo,
        locale: Locale
    ) -> String {
        guard let rate = Decimal.rateFromSubstrate(
            amount1: quote.amountIn,
            amount2: quote.expectedOut,
            precision1: inInfo.assetPrecision,
            precision2: outInfo.assetPrecision
        ) else {
            return ""
        }

        let inFormatter = formatterFactory.createTokenFormatter(for: inInfo).value(for: locale)
        let outFormatter = formatterFactory.createTokenFormatter(for: outInfo).value(for: locale)

        let oneIn = inFormatter.stringFromDecimal(1) ?? ""
        let rateOut = outFormatter.stringFromDecimal(rate) ?? ""

        return oneIn.estimatedEqual(to: rateOut)
    }

    func createBuyReceive(
        for quote: SubtensorTradeQuote,
        alphaInfo: AssetBalanceDisplayInfo,
        taoPrice: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let spotPrice = quote.quote.spotPrice
        let scale = SubtensorStakingPallet.alphaPriceScale

        return BalanceViewModel(
            amount: formatAmount(quote.expectedOut, displayInfo: alphaInfo, locale: locale).approximatelyEqual(),
            price: formatFiat(taoAmount: quote.expectedOut * spotPrice / scale, taoPrice: taoPrice, locale: locale)
        )
    }
}

extension SubtensorQuoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol {
    func createTradePanel(
        for quote: SubtensorTradeQuote?,
        amountIn: Balance?,
        direction: SubtensorTradeDirection,
        target: SubtensorStakeTarget,
        taoPrice: PriceData?,
        locale: Locale
    ) -> SubtensorTradePanelViewModel? {
        guard let quote, case .subnet = target else {
            return nil
        }

        let taoInfo = chainAsset.assetDisplayInfo
        let alphaInfo = target.assetDisplayInfo(basedOn: taoInfo)
        let hasReceive = amountIn == quote.amountIn

        switch (direction, quote.quote.args.direction) {
        case (.buy, .stake):
            let receive = createBuyReceive(
                for: quote,
                alphaInfo: alphaInfo,
                taoPrice: taoPrice,
                locale: locale
            )

            return SubtensorTradePanelViewModel(
                receive: hasReceive ? receive : nil,
                swapRate: formatSwapRate(for: quote, inInfo: taoInfo, outInfo: alphaInfo, locale: locale)
            )
        case (.sell, .unstake):
            let receive = BalanceViewModel(
                amount: formatAmount(quote.expectedOut, displayInfo: taoInfo, locale: locale).approximatelyEqual(),
                price: formatFiat(taoAmount: quote.expectedOut, taoPrice: taoPrice, locale: locale)
            )

            return SubtensorTradePanelViewModel(
                receive: hasReceive ? receive : nil,
                swapRate: formatSwapRate(for: quote, inInfo: alphaInfo, outInfo: taoInfo, locale: locale)
            )
        case (.buy, .unstake), (.sell, .stake):
            return nil
        }
    }

    func createSlippageViewModel(
        for tolerance: BigRational,
        locale: Locale
    ) -> String? {
        let formatter = NumberFormatter.percentSingleHalfEven
        formatter.locale = locale

        return formatter.stringFromDecimal(tolerance.decimalOrZeroValue)
    }

    func novaFeeDisclosure(locale: Locale) -> String {
        let percent = SwapBaseViewModelFactory.commissionPercent(
            rate: SubtensorNovaFeeRateStore.shared.rate,
            percentFormatter: NumberFormatter.percentSingleHalfEven.localizableResource(),
            locale: locale
        )

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiNovaFeeDisclosure(percent)
    }
}
