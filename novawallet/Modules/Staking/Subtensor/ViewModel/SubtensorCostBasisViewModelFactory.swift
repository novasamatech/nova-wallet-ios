import BigInt
import Foundation

enum SubtensorValueTone: Equatable {
    case neutral
    case positive
    case negative
}

struct SubtensorCostBasisValueViewModel: Equatable {
    let amount: String
    let detail: String?
    let tone: SubtensorValueTone
    let trend: SubtensorAvgBuyPriceTrend?

    init(amount: String, detail: String?, tone: SubtensorValueTone, trend: SubtensorAvgBuyPriceTrend? = nil) {
        self.amount = amount
        self.detail = detail
        self.tone = tone
        self.trend = trend
    }
}

enum SubtensorCostBasisRowViewModel: Equatable {
    case hidden
    case loading
    case value(SubtensorCostBasisValueViewModel)
}

struct SubtensorSaleCostBasisViewModel: Equatable {
    static let hidden = SubtensorSaleCostBasisViewModel(avgBuyPrice: .hidden, earned: .hidden, isEarnedEstimated: false)

    let avgBuyPrice: SubtensorCostBasisRowViewModel
    let earned: SubtensorCostBasisRowViewModel
    let isEarnedEstimated: Bool
}

final class SubtensorCostBasisViewModelFactory {
    let taoInfo: AssetBalanceDisplayInfo
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private let formatterFactory = AssetBalanceFormatterFactory()

    init(taoInfo: AssetBalanceDisplayInfo, balanceViewModelFactory: BalanceViewModelFactoryProtocol) {
        self.taoInfo = taoInfo
        self.balanceViewModelFactory = balanceViewModelFactory
    }
}

private extension SubtensorCostBasisViewModelFactory {
    enum Constants {
        static let plusSign = "+"
        static let minusSign = "\u{2212}"
    }

    func createUnknownValue(locale: Locale) -> SubtensorCostBasisRowViewModel {
        let unknown = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()

        return .value(SubtensorCostBasisValueViewModel(amount: unknown, detail: nil, tone: .neutral))
    }

    func createNoPurchasesValue(locale: Locale) -> SubtensorCostBasisRowViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return .value(
            SubtensorCostBasisValueViewModel(
                amount: strings.stakingSubtensorUiAvgBuyPriceNotAvailable(),
                detail: strings.stakingSubtensorUiAvgBuyPriceNoPurchases(),
                tone: .neutral
            )
        )
    }

    func createAverageValue(
        for totals: SubtensorPurchaseTotals,
        alphaSymbol: String,
        locale: Locale
    ) -> SubtensorCostBasisRowViewModel {
        let formatter = formatterFactory.createTokenFormatter(for: taoInfo).value(for: locale)

        guard let average = totals.averagePrice.decimalValue, let price = formatter.stringFromDecimal(average) else {
            return createUnknownValue(locale: locale)
        }

        let perAlpha = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSubtensorUiAvgBuyPricePerFormat(alphaSymbol)

        return .value(SubtensorCostBasisValueViewModel(amount: price, detail: perAlpha, tone: .neutral))
    }

    func createProjectedAverageValue(
        from current: SubtensorPurchaseTotals,
        to projected: SubtensorPurchaseTotals,
        alphaSymbol: String,
        locale: Locale
    ) -> SubtensorCostBasisRowViewModel {
        let priceFormatter = formatterFactory.createTokenFormatter(for: taoInfo).value(for: locale)
        let numberFormatter = formatterFactory.createDisplayFormatter(for: taoInfo).value(for: locale)

        guard
            let currentAverage = current.averagePrice.decimalValue,
            let projectedAverage = projected.averagePrice.decimalValue,
            let price = priceFormatter.stringFromDecimal(projectedAverage),
            let currentPrice = numberFormatter.stringFromDecimal(currentAverage) else {
            return createUnknownValue(locale: locale)
        }

        let fromCurrent = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSubtensorUiAvgBuyPriceFromFormat(currentPrice, alphaSymbol)

        return .value(
            SubtensorCostBasisValueViewModel(
                amount: price,
                detail: fromCurrent,
                tone: .neutral,
                trend: current.averageTrend(to: projected)
            )
        )
    }

    func createEarnedValue(
        _ earned: BigInt,
        taoPrice: PriceData?,
        locale: Locale
    ) -> SubtensorCostBasisValueViewModel {
        let balance = balanceViewModelFactory.balanceFromPrice(
            earned.magnitude.decimal(assetInfo: taoInfo),
            priceData: taoPrice
        ).value(for: locale)

        if earned > 0 {
            return SubtensorCostBasisValueViewModel(
                amount: Constants.plusSign + balance.amount,
                detail: balance.price?.approximatelyEqual(),
                tone: .positive
            )
        }

        if earned < 0 {
            return SubtensorCostBasisValueViewModel(
                amount: Constants.minusSign + balance.amount,
                detail: balance.price.map { (Constants.minusSign + $0).approximatelyEqual() },
                tone: .negative
            )
        }

        return SubtensorCostBasisValueViewModel(
            amount: balance.amount,
            detail: balance.price?.approximatelyEqual(),
            tone: .neutral
        )
    }
}

extension SubtensorCostBasisViewModelFactory {
    func createAvgBuyPrice(
        for costBasis: SubtensorCostBasisState,
        alphaSymbol: String,
        locale: Locale
    ) -> SubtensorCostBasisRowViewModel {
        switch costBasis {
        case .loading:
            return .loading
        case .unavailable:
            return createUnknownValue(locale: locale)
        case .resolved(.noPurchases):
            return createNoPurchasesValue(locale: locale)
        case let .resolved(.average(totals)):
            return createAverageValue(for: totals, alphaSymbol: alphaSymbol, locale: locale)
        }
    }

    func createAvgBuyPrice(
        for costBasis: SubtensorCostBasisState?,
        after purchase: SubtensorPurchaseQuote,
        alphaSymbol: String,
        locale: Locale
    ) -> SubtensorCostBasisRowViewModel {
        guard let costBasis else {
            return .hidden
        }

        guard case let .resolved(.average(totals)) = costBasis else {
            return createAvgBuyPrice(for: costBasis, alphaSymbol: alphaSymbol, locale: locale)
        }

        switch purchase {
        case .empty, .unknown:
            return createAverageValue(for: totals, alphaSymbol: alphaSymbol, locale: locale)
        case .pending:
            return .loading
        case let .quoted(tao, alpha):
            return createProjectedAverageValue(
                from: totals,
                to: totals.adding(paidTao: tao, receivedAlpha: alpha),
                alphaSymbol: alphaSymbol,
                locale: locale
            )
        }
    }

    func createEarned(
        for costBasis: SubtensorCostBasisState,
        proceeds: SubtensorSaleProceeds,
        taoPrice: PriceData?,
        locale: Locale
    ) -> SubtensorCostBasisRowViewModel {
        if let earned = costBasis.earnedTao(from: proceeds) {
            return .value(createEarnedValue(earned, taoPrice: taoPrice, locale: locale))
        }

        switch (costBasis, proceeds) {
        case (.loading, .pending), (.loading, .quoted), (.resolved(.average), .pending):
            return .loading
        default:
            return createUnknownValue(locale: locale)
        }
    }

    func createSale(
        for costBasis: SubtensorCostBasisState?,
        proceeds: SubtensorSaleProceeds,
        alphaSymbol: String,
        taoPrice: PriceData?,
        locale: Locale
    ) -> SubtensorSaleCostBasisViewModel {
        guard let costBasis else {
            return .hidden
        }

        return SubtensorSaleCostBasisViewModel(
            avgBuyPrice: createAvgBuyPrice(for: costBasis, alphaSymbol: alphaSymbol, locale: locale),
            earned: createEarned(for: costBasis, proceeds: proceeds, taoPrice: taoPrice, locale: locale),
            isEarnedEstimated: costBasis.earnedTao(from: proceeds) != nil
        )
    }
}
