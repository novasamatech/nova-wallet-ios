import Foundation
import Foundation_iOS

protocol SubnetDetailsViewModelFactoryProtocol {
    func createTitle(subnetLogos: SubtensorSubnetLogos?, locale: Locale) -> SubtensorSubnetDetailsTitleViewModel

    func createViewModel(
        for state: SubtensorSubnetDetailsState,
        isUseEnabled: Bool,
        locale: Locale
    ) -> SubtensorSubnetDetailsViewModel

    func createPriceHeader(
        for state: SubtensorSubnetDetailsState,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel
}

final class SubtensorSubnetDetailsViewModelFactory {
    static let chipAmounts: [Decimal] = [1, 5, 10]
    static let defaultChip = SubtensorSubnetAmountChip.fixed(5)

    let subnet: SubtensorCatalogueSubnet
    let chainAsset: ChainAsset
    let currency: Currency
    let iconFactory: SubtensorSubnetIconFactoryProtocol
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol
    let priceWidgetFactory: SubtensorPriceWidgetFactoryProtocol

    let tokenFormatter: LocalizableResource<TokenFormatter>
    let alphaFormatter: LocalizableResource<TokenFormatter>
    let compactTokenFormatter: LocalizableResource<TokenFormatter>

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

        priceWidgetFactory = SubtensorPriceWidgetViewModelFactory(
            chainAsset: chainAsset,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formatterFactory: formatterFactory
        )

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
    func createPriceWidgetParams(
        for state: SubtensorSubnetDetailsState,
        locale: Locale
    ) -> SubtensorPriceWidgetParams {
        let caption = priceWidgetFactory.createCaption(
            subnetTitle: SubtensorSubnetNaming.titleWithSymbol(for: subnet, locale: locale),
            stamps: subnet.stamps,
            now: state.now,
            locale: locale
        )

        let currencyViewModel = SubtensorSubnetCurrencyViewModel(
            titles: [chainAsset.assetDisplayInfo.symbol, currency.code],
            selectedIndex: state.isFiat ? 1 : 0,
            isEnabled: state.taoPrice != nil || state.isFiat
        )

        return SubtensorPriceWidgetParams(
            caption: caption,
            spotPrice: subnet.taoPerAlpha.decimal(assetInfo: chainAsset.assetDisplayInfo),
            history: state.history,
            period: state.period,
            isFiat: state.isFiat,
            taoPrice: state.taoPrice,
            currencyId: currency.id,
            currency: currencyViewModel,
            selectedPoint: state.chartPoint
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
            priceWidget: priceWidgetFactory.createWidget(
                for: createPriceWidgetParams(for: state, locale: locale),
                locale: locale
            ),
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

    func createPriceHeader(
        for state: SubtensorSubnetDetailsState,
        locale: Locale
    ) -> SubtensorSubnetPriceHeaderViewModel {
        priceWidgetFactory.createHeader(for: createPriceWidgetParams(for: state, locale: locale), locale: locale)
    }
}

private extension String {
    func isolatedLeftToRight() -> String {
        "\u{2066}\(self)\u{2069}"
    }
}
