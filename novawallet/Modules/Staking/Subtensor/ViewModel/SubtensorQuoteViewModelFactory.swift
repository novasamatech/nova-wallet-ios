import BigInt
import Foundation

struct SubtensorStakeTargetViewModel {
    let title: String
    let subtitle: String?
    let isRoot: Bool
}

struct SubtensorTradePanelViewModel {
    let receive: BalanceViewModelProtocol?
    let swapRate: String
    let earnPerMonth: BalanceViewModelProtocol?
}

struct SubtensorQuotePanelViewModel {
    let receive: String
    let poolFee: String
    let priceImpact: String
    let isImpactHigh: Bool
}

protocol SubtensorQuoteViewModelFactoryProtocol {
    func createTargetViewModel(
        for target: SubtensorStakeTarget,
        locale: Locale
    ) -> SubtensorStakeTargetViewModel

    func createQuotePanel(
        for quote: SubtensorQuote?,
        target: SubtensorStakeTarget,
        locale: Locale
    ) -> SubtensorQuotePanelViewModel?

    func createTradePanel(
        for quote: SubtensorTradeQuote?,
        amountIn: Balance?,
        direction: SubtensorTradeDirection,
        target: SubtensorStakeTarget,
        annualRate: Decimal?,
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

    func createBuyValues(
        for quote: SubtensorTradeQuote,
        alphaInfo: AssetBalanceDisplayInfo,
        annualRate: Decimal?,
        taoPrice: PriceData?,
        locale: Locale
    ) -> (receive: BalanceViewModelProtocol, earnPerMonth: BalanceViewModelProtocol?) {
        let spotPrice = quote.quote.spotPrice
        let scale = SubtensorStakingPallet.alphaPriceScale

        let receive = BalanceViewModel(
            amount: formatAmount(quote.expectedOut, displayInfo: alphaInfo, locale: locale).approximatelyEqual(),
            price: formatFiat(taoAmount: quote.expectedOut * spotPrice / scale, taoPrice: taoPrice, locale: locale)
        )

        guard let annualRate, let rate = BigRational.fraction(from: annualRate) else {
            return (receive, nil)
        }

        let monthly = SubtensorEarningsEstimator.monthly(amount: quote.expectedOut, annualRate: rate)

        let earnPerMonth = BalanceViewModel(
            amount: formatAmount(monthly, displayInfo: alphaInfo, locale: locale).approximatelyEqual(),
            price: formatFiat(taoAmount: monthly * spotPrice / scale, taoPrice: taoPrice, locale: locale)?
                .approximatelyEqual()
        )

        return (receive, earnPerMonth)
    }

    func formatPercent(_ value: BigRational, locale: Locale) -> String {
        let formatter = NumberFormatter.percentSingle
        formatter.locale = locale

        return formatter.stringFromDecimal(value.decimalOrZeroValue) ?? ""
    }
}

extension SubtensorQuoteViewModelFactory: SubtensorQuoteViewModelFactoryProtocol {
    func createTargetViewModel(
        for target: SubtensorStakeTarget,
        locale: Locale
    ) -> SubtensorStakeTargetViewModel {
        switch target {
        case .root:
            return SubtensorStakeTargetViewModel(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.stakingSubtensorUiRootStaking(),
                subtitle: nil,
                isRoot: true
            )
        case let .subnet(info, _):
            let symbol = info.displaySymbol
            let name = info.displayName

            return SubtensorStakeTargetViewModel(
                title: name.isEmpty
                    ? R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiSubnetFormat(
                        Int(info.netuid)
                    )
                    : name,
                subtitle: symbol.isEmpty ? nil : symbol,
                isRoot: false
            )
        }
    }

    func createQuotePanel(
        for quote: SubtensorQuote?,
        target: SubtensorStakeTarget,
        locale: Locale
    ) -> SubtensorQuotePanelViewModel? {
        guard case .subnet = target, let quote else {
            return nil
        }

        let receiveDisplayInfo: AssetBalanceDisplayInfo
        let feeDisplayInfo: AssetBalanceDisplayInfo

        switch quote.args.direction {
        case .stake:
            receiveDisplayInfo = target.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo)
            feeDisplayInfo = chainAsset.assetDisplayInfo
        case .unstake:
            receiveDisplayInfo = chainAsset.assetDisplayInfo
            feeDisplayInfo = target.assetDisplayInfo(basedOn: chainAsset.assetDisplayInfo)
        }

        let receive = formatAmount(
            quote.expectedOut,
            displayInfo: receiveDisplayInfo,
            locale: locale
        )

        let poolFeeAmount = formatAmount(
            quote.poolFee,
            displayInfo: feeDisplayInfo,
            locale: locale
        )

        let feeRatePercent = formatPercent(
            BigRational(
                numerator: BigUInt(quote.feeRate),
                denominator: BigUInt(SubtensorStakingPallet.perU16Denominator)
            ),
            locale: locale
        )

        let impact = quote.priceImpact ?? BigRational(numerator: 0, denominator: 1)

        return SubtensorQuotePanelViewModel(
            receive: receive.approximately(),
            poolFee: R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiJoinSpaceFormat(
                poolFeeAmount,
                feeRatePercent.inParenthesis()
            ),
            priceImpact: formatPercent(impact, locale: locale),
            isImpactHigh: SubtensorStakingFlowConstants.isHighPriceImpact(impact)
        )
    }

    func createTradePanel(
        for quote: SubtensorTradeQuote?,
        amountIn: Balance?,
        direction: SubtensorTradeDirection,
        target: SubtensorStakeTarget,
        annualRate: Decimal?,
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
            let values = createBuyValues(
                for: quote,
                alphaInfo: alphaInfo,
                annualRate: annualRate,
                taoPrice: taoPrice,
                locale: locale
            )

            return SubtensorTradePanelViewModel(
                receive: hasReceive ? values.receive : nil,
                swapRate: formatSwapRate(for: quote, inInfo: taoInfo, outInfo: alphaInfo, locale: locale),
                earnPerMonth: hasReceive ? values.earnPerMonth : nil
            )
        case (.sell, .unstake):
            let receive = BalanceViewModel(
                amount: formatAmount(quote.expectedOut, displayInfo: taoInfo, locale: locale).approximatelyEqual(),
                price: formatFiat(taoAmount: quote.expectedOut, taoPrice: taoPrice, locale: locale)
            )

            return SubtensorTradePanelViewModel(
                receive: hasReceive ? receive : nil,
                swapRate: formatSwapRate(for: quote, inInfo: alphaInfo, outInfo: taoInfo, locale: locale),
                earnPerMonth: nil
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
            rate: SubtensorNovaFeeConstants.rate,
            percentFormatter: NumberFormatter.percentSingleHalfEven.localizableResource(),
            locale: locale
        )

        return R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiNovaFeeDisclosure(percent)
    }
}
