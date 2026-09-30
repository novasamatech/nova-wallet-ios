import Foundation
import Foundation_iOS

protocol SubnetDetailsViewModelFactoryProtocol {
    func createTitle(subnetLogos: SubtensorSubnetLogos?, locale: Locale) -> SubtensorSubnetDetailsTitleViewModel

    func createViewModel(
        for state: SubtensorSubnetDetailsState,
        isUseEnabled: Bool,
        locale: Locale
    ) -> SubtensorSubnetDetailsViewModel

    func createFactors(for state: SubtensorSubnetDetailsState, locale: Locale) -> SubtensorSubnetFactorsViewModel
}

final class SubtensorSubnetDetailsViewModelFactory {
    static let chipAmounts: [Decimal] = [1, 5, 10]
    static let defaultChip = SubtensorSubnetAmountChip.fixed(5)
    static let periods: [SubtensorPricePeriod] = [.day, .week, .month, .quarter, .year]
    static let defaultPeriod = SubtensorPricePeriod.week

    let subnet: SubtensorCatalogueSubnet
    let chainAsset: ChainAsset
    let currency: Currency
    let iconFactory: SubtensorSubnetIconFactoryProtocol
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol

    let tokenFormatter: LocalizableResource<TokenFormatter>
    let alphaFormatter: LocalizableResource<TokenFormatter>
    let compactTokenFormatter: LocalizableResource<TokenFormatter>
    let axisFormatter: LocalizableResource<LocalizableDecimalFormatting>
    let fiatAxisFormatter: LocalizableResource<TokenFormatter>
    let balanceViewModelFactory: PrimitiveBalanceViewModelFactoryProtocol

    init(
        subnet: SubtensorCatalogueSubnet,
        chainAsset: ChainAsset,
        currency: Currency,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        iconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory(),
        displayAddressFactory: DisplayAddressViewModelFactoryProtocol = DisplayAddressViewModelFactory(),
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.subnet = subnet
        self.chainAsset = chainAsset
        self.currency = currency
        self.iconFactory = iconFactory
        self.displayAddressFactory = displayAddressFactory

        let taoInfo = chainAsset.assetDisplayInfo

        let alphaInfo = AssetBalanceDisplayInfo(
            displayPrecision: taoInfo.displayPrecision,
            assetPrecision: taoInfo.assetPrecision,
            symbol: SubtensorSubnetNaming.symbol(for: subnet),
            symbolValueSeparator: taoInfo.symbolValueSeparator,
            symbolPosition: taoInfo.symbolPosition,
            icon: nil
        )

        tokenFormatter = formatterFactory.createTokenFormatter(for: taoInfo)
        alphaFormatter = formatterFactory.createTokenFormatter(for: alphaInfo)
        compactTokenFormatter = formatterFactory.createCompactTokenFormatter(for: taoInfo)
        axisFormatter = formatterFactory.createDisplayFormatter(for: taoInfo)
        fiatAxisFormatter = formatterFactory.createAssetPriceFormatter(
            for: priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currency.id)
        )
        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: taoInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }
}

extension SubtensorSubnetDetailsViewModelFactory {
    func unknownValue(for locale: Locale) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
    }

    func formatAlpha(_ amount: Balance, locale: Locale) -> String {
        let decimal = amount.decimal(assetInfo: chainAsset.assetDisplayInfo)
        let text = alphaFormatter.value(for: locale).stringFromDecimal(decimal) ?? unknownValue(for: locale)

        return text.isolatedLeftToRight()
    }

    func formatTao(_ amount: Decimal, locale: Locale) -> String {
        tokenFormatter.value(for: locale).stringFromDecimal(amount) ?? unknownValue(for: locale)
    }

    func formatCompactTao(_ amount: Decimal, locale: Locale) -> String {
        compactTokenFormatter.value(for: locale).stringFromDecimal(amount) ?? unknownValue(for: locale)
    }

    func formatPercent(_ value: Decimal, locale: Locale) -> String {
        let formatter = NumberFormatter.percentSingle
        formatter.locale = locale

        return formatter.stringFromDecimal(value) ?? unknownValue(for: locale)
    }

    func formatCount(_ value: Int, locale: Locale) -> String {
        let formatter = NumberFormatter.quantity
        formatter.locale = locale

        return formatter.string(from: NSNumber(value: value)) ?? unknownValue(for: locale)
    }
}

private extension SubtensorSubnetDetailsViewModelFactory {
    func periodTitle(for period: SubtensorPricePeriod, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let title: String

        switch period {
        case .day:
            title = strings.commonPeriod1d()
        case .week:
            title = strings.commonPeriod7d()
        case .month:
            title = strings.commonPeriod1m()
        case .quarter:
            title = strings.commonPeriod3m()
        case .year:
            title = strings.commonPeriod1y()
        case .all:
            title = strings.commonPeriodAll()
        }

        return title.uppercased(with: locale)
    }

    func selectedSeries(of history: SubtensorPriceHistory, isFiat: Bool) -> (values: [Double], change: Decimal?) {
        let values = history.points
            .map { NSDecimalNumber(decimal: isFiat ? $0.fiatPerAlpha : $0.taoPerAlpha).doubleValue }
            .filter(\.isFinite)

        return (values, isFiat ? history.changeInFiat : history.changeInTao)
    }

    func createHeader(for state: SubtensorSubnetDetailsState, locale: Locale) -> SubtensorSubnetPriceHeaderViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let spot = subnet.taoPerAlpha.decimal(assetInfo: chainAsset.assetDisplayInfo)

        let price: String

        if state.isFiat {
            price = state.taoPrice.map { priceData in
                balanceViewModelFactory.priceFromAmount(spot, priceData: priceData).value(for: locale)
            } ?? unknownValue(for: locale)
        } else {
            price = formatTao(spot, locale: locale)
        }

        return SubtensorSubnetPriceHeaderViewModel(
            caption: strings.stakingSubtensorUiDetailPriceFormat(
                SubtensorSubnetNaming.titleWithSymbol(for: subnet, locale: locale)
            ),
            price: price,
            change: createChange(for: state, locale: locale),
            currencies: [chainAsset.assetDisplayInfo.symbol, currency.code],
            selectedCurrencyIndex: state.isFiat ? 1 : 0,
            isCurrencyEnabled: state.taoPrice != nil || state.isFiat
        )
    }

    func createChange(
        for state: SubtensorSubnetDetailsState,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel.Change {
        switch state.history {
        case .loading:
            return .loading
        case .notListed, .failed:
            return .hidden
        case let .available(history):
            let formatter = NumberFormatter.signedPercentSingle
            formatter.locale = locale

            guard
                let change = selectedSeries(of: history, isFiat: state.isFiat).change,
                let percent = formatter.stringFromDecimal(change) else {
                return .hidden
            }

            let text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiJoinDotFormat(
                percent,
                periodTitle(for: state.period, locale: locale)
            )

            return .value(text: text, isRising: change >= 0)
        }
    }

    func createUnavailableChart(locale: Locale) -> SubtensorSubnetChartViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return .unavailable(
            title: strings.stakingSubtensorUiDetailHistoryUnavailable(),
            details: strings.stakingSubtensorUiDetailHistorySource()
        )
    }

    func formatAxis(_ value: Double, isFiat: Bool, locale: Locale) -> String {
        let decimal = Decimal(value)

        let text = isFiat
            ? fiatAxisFormatter.value(for: locale).stringFromDecimal(decimal)
            : axisFormatter.value(for: locale).stringFromDecimal(decimal)

        return text ?? unknownValue(for: locale)
    }

    func createChart(for state: SubtensorSubnetDetailsState, locale: Locale) -> SubtensorSubnetChartViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch state.history {
        case .loading:
            return .loading
        case .notListed:
            return createUnavailableChart(locale: locale)
        case .failed:
            return .failed(title: strings.stakingSubtensorUiDetailHistoryFailed(), action: strings.commonTryAgain())
        case let .available(history):
            let series = selectedSeries(of: history, isFiat: state.isFiat)

            guard
                series.values.count > 1,
                let first = series.values.first,
                let last = series.values.last,
                let minimum = series.values.min(),
                let maximum = series.values.max() else {
                return createUnavailableChart(locale: locale)
            }

            return .chart(
                SubtensorPriceChartViewModel(
                    values: series.values,
                    axisLabels: [
                        formatAxis(maximum, isFiat: state.isFiat, locale: locale),
                        formatAxis(minimum, isFiat: state.isFiat, locale: locale)
                    ],
                    isRising: series.change.map { $0 >= 0 } ?? (last >= first)
                )
            )
        }
    }

    func createPeriods(for state: SubtensorSubnetDetailsState, locale: Locale) -> SubtensorSubnetPeriodsViewModel {
        SubtensorSubnetPeriodsViewModel(
            titles: Self.periods.map { periodTitle(for: $0, locale: locale) },
            selectedIndex: Self.periods.firstIndex(of: state.period) ?? 0,
            isEnabled: state.history != .notListed
        )
    }

    func createValidator(
        for state: SubtensorSubnetDetailsState,
        locale: Locale
    ) -> SubtensorSubnetValidatorRowViewModel {
        switch state.validator {
        case .pending:
            return .loading
        case .unselected:
            return .unselected(
                R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiDetailChooseValidator()
            )
        case let .selected(item):
            let address = try? item.hotkey.toAddress(using: chainAsset.chain.chainFormat)

            let icon = address.flatMap { address in
                displayAddressFactory.createViewModel(
                    from: DisplayAddress(address: address, username: item.name ?? "")
                ).imageViewModel
            }

            let apy = SubtensorAlphaApyFormatter.annualRate(for: item.hotkey, in: state.yields).map { rate in
                SubtensorApyFormatter.text(for: rate, style: .trailing, locale: locale)
            }

            return .selected(
                name: item.name ?? address?.mediumTruncated ?? unknownValue(for: locale),
                icon: icon,
                apy: apy
            )
        }
    }
}

extension SubtensorSubnetDetailsViewModelFactory: SubnetDetailsViewModelFactoryProtocol {
    func createTitle(subnetLogos: SubtensorSubnetLogos?, locale: Locale) -> SubtensorSubnetDetailsTitleViewModel {
        SubtensorSubnetDetailsTitleViewModel(
            title: SubtensorSubnetNaming.titleWithSymbol(for: subnet, locale: locale),
            icon: iconFactory.icon(for: subnet, logos: subnetLogos)
        )
    }

    func createViewModel(
        for state: SubtensorSubnetDetailsState,
        isUseEnabled: Bool,
        locale: Locale
    ) -> SubtensorSubnetDetailsViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorSubnetDetailsViewModel(
            header: createHeader(for: state, locale: locale),
            chart: createChart(for: state, locale: locale),
            periods: createPeriods(for: state, locale: locale),
            validator: createValidator(for: state, locale: locale),
            estimate: createEstimate(for: state, locale: locale),
            factors: createFactors(for: state, locale: locale),
            subnetNumber: String(subnet.netuid),
            isFavorite: state.isFavorite,
            favoriteAccessibilityLabel: state.isFavorite
                ? strings.stakingSubtensorUiDetailFavoriteRemove()
                : strings.dappFavoriteAddTitle(),
            isUseEnabled: isUseEnabled
        )
    }
}

private extension String {
    func isolatedLeftToRight() -> String {
        "\u{2066}\(self)\u{2069}"
    }
}
