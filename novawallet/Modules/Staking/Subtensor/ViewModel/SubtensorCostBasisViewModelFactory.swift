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
}

enum SubtensorCostBasisRowViewModel: Equatable {
    case hidden
    case loading
    case value(SubtensorCostBasisValueViewModel)
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
}
