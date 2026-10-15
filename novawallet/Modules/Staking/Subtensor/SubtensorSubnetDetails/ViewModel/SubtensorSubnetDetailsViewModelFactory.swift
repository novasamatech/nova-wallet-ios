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
    let subnet: SubtensorCatalogueSubnet
    let chainAsset: ChainAsset
    let currency: Currency
    let iconFactory: SubtensorSubnetIconFactoryProtocol
    let displayAddressFactory: DisplayAddressViewModelFactoryProtocol
    let priceWidgetFactory: SubtensorPriceWidgetFactoryProtocol

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

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

        balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let taoInfo = chainAsset.assetDisplayInfo

        tokenFormatter = formatterFactory.createTokenFormatter(for: taoInfo)
        alphaFormatter = formatterFactory.createTokenFormatter(
            for: taoInfo.subtensorAlpha(symbol: SubtensorSubnetNaming.symbol(for: subnet))
        )
        compactTokenFormatter = formatterFactory.createCompactTokenFormatter(for: taoInfo)
    }
}

extension SubtensorSubnetDetailsViewModelFactory {
    func formatAlpha(_ amount: Balance, locale: Locale) -> String {
        let decimal = amount.decimal(assetInfo: chainAsset.assetDisplayInfo)
        let text = alphaFormatter.value(for: locale).stringFromDecimal(decimal) ?? .subtensorUnknown(for: locale)

        return SubtensorSubnetNaming.isolatedLeftToRight(text)
    }

    func formatTao(_ amount: Decimal, locale: Locale) -> String {
        tokenFormatter.value(for: locale).stringFromDecimal(amount) ?? .subtensorUnknown(for: locale)
    }

    func formatCompactTao(_ amount: Decimal, locale: Locale) -> String {
        compactTokenFormatter.value(for: locale).stringFromDecimal(amount) ?? .subtensorUnknown(for: locale)
    }

    func formatPercent(_ value: Decimal, maximumFractionDigits: Int = 2, locale: Locale) -> String {
        let formatter = NumberFormatter.subtensorPercentSingle.value(for: locale)
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.roundingMode = .halfEven

        return formatter.stringFromDecimal(value) ?? .subtensorUnknown(for: locale)
    }

    func formatCount(_ value: Int, locale: Locale) -> String {
        let formatter = NumberFormatter.quantity
        formatter.locale = locale

        return formatter.string(from: NSNumber(value: value)) ?? .subtensorUnknown(for: locale)
    }
}

private extension SubtensorSubnetDetailsViewModelFactory {
    func createPriceWidgetParams(for state: SubtensorSubnetDetailsState) -> SubtensorPriceWidgetParams {
        SubtensorPriceWidgetParams(
            history: state.history,
            period: state.period,
            isFiat: state.isFiat,
            taoPrice: state.taoPrice,
            currencyId: currency.id,
            chartEndDate: state.chartEndDate
        )
    }

    func createPriceHeaderParams(
        for state: SubtensorSubnetDetailsState,
        locale: Locale
    ) -> SubtensorPriceHeaderParams {
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

        return SubtensorPriceHeaderParams(
            caption: caption,
            spotPrice: subnet.taoPerAlpha.decimal(assetInfo: chainAsset.assetDisplayInfo),
            currency: currencyViewModel,
            selection: state.chartSelection
        )
    }

    func createValidator(
        for state: SubtensorSubnetDetailsState,
        locale: Locale
    ) -> SubtensorValidatorCardViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let item = state.validator.item
        let address = item.flatMap { try? $0.hotkey.toAddress(using: chainAsset.chain.chainFormat) }
        let display = address.map {
            displayAddressFactory.createViewModel(from: DisplayAddress(address: $0, username: item?.name ?? ""))
        }
        let rate = item.flatMap { SubtensorAlphaApyFormatter.annualRate(for: $0.hotkey, in: state.yields) }
        let name: String? = state.validator == .pending ? nil : item?.name ?? address?.mediumTruncated ??
            strings.stakingSubtensorUiDetailChooseValidator()
        return SubtensorValidatorCardViewModel(
            icon: display?.imageViewModel,
            name: name,
            subtitle: strings.stakingCommonValidator(),
            rate: item == nil ? .hidden : .value(SubtensorApyFormatter.text(for: rate, style: .bare, locale: locale)),
            rateCaption: strings.stakingSubtensorV22EstApy()
        )
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
                for: createPriceWidgetParams(for: state),
                header: createPriceHeaderParams(for: state, locale: locale),
                locale: locale
            ),
            validator: createValidator(for: state, locale: locale),
            parameters: createParameters(for: state, locale: locale),
            moreDetails: createMoreDetails(for: state, locale: locale),
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
        priceWidgetFactory.createHeader(
            createPriceHeaderParams(for: state, locale: locale),
            for: createPriceWidgetParams(for: state),
            locale: locale
        )
    }
}
