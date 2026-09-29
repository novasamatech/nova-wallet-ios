import Foundation
import Foundation_iOS

struct SubtensorSubnetSelectViewModel {
    enum Change {
        case loading
        case value(text: String, isRising: Bool, sparkline: [Double])
        case unavailable(String)
        case notListed(String)
    }

    let subnetRef: SubtensorSubnetRef
    let icon: ImageViewModelProtocol
    let title: String
    let subtitle: String?
    let price: String
    let change: Change
    let isFavorite: Bool
    let favoriteAccessibilityLabel: String
    let favoriteAccessibilityValue: String
}

struct SubtensorSubnetListViewModel {
    enum Content {
        case loading
        case rows(picks: [SubtensorSubnetSelectViewModel], others: [SubtensorSubnetSelectViewModel])
        case empty(String)
    }

    let chipTitle: String
    let caption: String?
    let isFilterActive: Bool
    let areControlsEnabled: Bool
    let content: Content
}

struct SubtensorStakeToRootBarViewModel {
    let icon: ImageViewModelProtocol
    let title: String
    let subtitle: String
}

struct SubtensorSubnetListState {
    let list: SubtensorSubnetList?
    let isRowsLoading: Bool
    let sort: SubtensorSubnetSort
    let filters: SubtensorSubnetFilters
    let config: SubtensorEarnConfig?
}

protocol SubtensorSubnetViewModelFactoryProtocol {
    func createRowViewModel(
        for item: SubtensorSubnetListItem,
        isFavorite: Bool,
        config: SubtensorEarnConfig?,
        locale: Locale
    ) -> SubtensorSubnetSelectViewModel

    func createListViewModel(for state: SubtensorSubnetListState, locale: Locale) -> SubtensorSubnetListViewModel

    func createRootBarViewModel(annualRate: Decimal?, locale: Locale) -> SubtensorStakeToRootBarViewModel

    func createSortSheetViewModel(selected: SubtensorSubnetSort, locale: Locale) -> SubtensorSortSheetViewModel

    func createFiltersViewModel(
        filters: SubtensorSubnetFilters,
        count: Int?,
        isThirtyDayUnavailable: Bool,
        locale: Locale
    ) -> SubtensorSubnetFiltersViewModel
}

final class SubtensorSubnetViewModelFactory {
    let chainAsset: ChainAsset
    let iconFactory: SubtensorSubnetIconFactoryProtocol
    let assetIconFactory: AssetIconViewModelFactoryProtocol

    private let tokenFormatter: LocalizableResource<TokenFormatter>
    private let compactTokenFormatter: LocalizableResource<TokenFormatter>
    private let changeFormatter: LocalizableResource<NumberFormatter>

    init(
        chainAsset: ChainAsset,
        iconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory(),
        assetIconFactory: AssetIconViewModelFactoryProtocol = AssetIconViewModelFactory(),
        balanceFormatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.chainAsset = chainAsset
        self.iconFactory = iconFactory
        self.assetIconFactory = assetIconFactory

        tokenFormatter = balanceFormatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo)
        compactTokenFormatter = balanceFormatterFactory.createCompactTokenFormatter(for: chainAsset.assetDisplayInfo)
        changeFormatter = NumberFormatter.signedPercentSingle.localizableResource()
    }
}

private extension SubtensorSubnetViewModelFactory {
    func formatTokenAmount(
        _ amount: Balance,
        formatter: LocalizableResource<TokenFormatter>,
        locale: Locale
    ) -> String {
        let decimal = amount.decimal(assetInfo: chainAsset.assetDisplayInfo)

        return formatter.value(for: locale).stringFromDecimal(decimal) ??
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorUiValueUnknown()
    }

    func createChange(
        for weekly: SubtensorPriceData<SubtensorWeeklyPriceSummary>?,
        locale: Locale
    ) -> SubtensorSubnetSelectViewModel.Change {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch weekly {
        case .none:
            return .loading
        case .notListed:
            return .notListed(strings.stakingSubtensorUiPickerNoHistory())
        case .unavailable:
            return .unavailable(strings.stakingSubtensorUiValueUnknown())
        case let .available(summary):
            guard let percent = changeFormatter.value(for: locale).stringFromDecimal(summary.change) else {
                return .unavailable(strings.stakingSubtensorUiValueUnknown())
            }

            return .value(
                text: strings.stakingSubtensorUiJoinSpaceFormat(percent, strings.commonPeriod7d()),
                isRising: summary.change >= 0,
                sparkline: summary.sparkline.map { NSDecimalNumber(decimal: $0).doubleValue }
            )
        }
    }

    func createRowViewModels(
        for items: [SubtensorSubnetListItem],
        isFavorite: Bool,
        config: SubtensorEarnConfig?,
        locale: Locale
    ) -> [SubtensorSubnetSelectViewModel] {
        items.map { createRowViewModel(for: $0, isFavorite: isFavorite, config: config, locale: locale) }
    }

    func createContent(
        for state: SubtensorSubnetListState,
        locale: Locale
    ) -> SubtensorSubnetListViewModel.Content {
        guard let list = state.list, !state.isRowsLoading else {
            return .loading
        }

        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch list.emptyKind {
        case let .query(query):
            return .empty(strings.stakingSubtensorUiPickerEmptyQueryFormat(query))
        case .filters:
            return .empty(strings.stakingSubtensorUiPickerEmpty())
        case .none:
            return .rows(
                picks: createRowViewModels(for: list.picks, isFavorite: true, config: state.config, locale: locale),
                others: createRowViewModels(for: list.others, isFavorite: false, config: state.config, locale: locale)
            )
        }
    }

    func chipTitle(for sort: SubtensorSubnetSort, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch sort {
        case .sevenDayChange:
            return strings.stakingSubtensorUiPickerChipSevenDay()
        case .thirtyDayChange:
            return strings.stakingSubtensorUiPickerChipThirtyDay()
        case .poolDepth:
            return strings.stakingSubtensorUiPickerPoolDepth()
        case .age:
            return strings.stakingSubtensorUiPickerAge()
        case .name:
            return strings.commonName()
        }
    }

    func sortPhrase(for sort: SubtensorSubnetSort, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch sort {
        case .sevenDayChange:
            return strings.stakingSubtensorUiPickerBySevenDay()
        case .thirtyDayChange:
            return strings.stakingSubtensorUiPickerByThirtyDay()
        case .poolDepth:
            return strings.stakingSubtensorUiPickerByPool()
        case .age:
            return strings.stakingSubtensorUiPickerByAge()
        case .name:
            return strings.stakingSubtensorUiPickerByName()
        }
    }

    func sortOption(for sort: SubtensorSubnetSort, locale: Locale) -> SubtensorSortSheetViewModel.Option {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch sort {
        case .sevenDayChange:
            return .init(
                title: strings.stakingSubtensorUiPickerSevenDay(),
                subtitle: strings.stakingSubtensorUiPickerSevenDayDetail()
            )
        case .thirtyDayChange:
            return .init(
                title: strings.stakingSubtensorUiPickerThirtyDay(),
                subtitle: strings.stakingSubtensorUiPickerThirtyDayDetail()
            )
        case .poolDepth:
            return .init(
                title: strings.stakingSubtensorUiPickerPoolDepth(),
                subtitle: strings.stakingSubtensorUiPickerPoolDetail()
            )
        case .age:
            return .init(
                title: strings.stakingSubtensorUiPickerAge(),
                subtitle: strings.stakingSubtensorUiPickerAgeDetail()
            )
        case .name:
            return .init(title: strings.commonName(), subtitle: strings.stakingSubtensorUiPickerNameDetail())
        }
    }
}

extension SubtensorSubnetViewModelFactory: SubtensorSubnetViewModelFactoryProtocol {
    func createRowViewModel(
        for item: SubtensorSubnetListItem,
        isFavorite: Bool,
        config: SubtensorEarnConfig?,
        locale: Locale
    ) -> SubtensorSubnetSelectViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorSubnetSelectViewModel(
            subnetRef: item.ref,
            icon: iconFactory.icon(for: item.subnet, config: config),
            title: SubtensorSubnetNaming.titleWithSymbol(for: item.subnet, locale: locale),
            subtitle: item.weekly == .notListed ? strings.stakingSubtensorUiPickerOnchainRatio() : nil,
            price: formatTokenAmount(item.subnet.taoPerAlpha, formatter: tokenFormatter, locale: locale),
            change: createChange(for: item.weekly, locale: locale),
            isFavorite: isFavorite,
            favoriteAccessibilityLabel: strings.stakingSubtensorUiPickerFavoriteAccessibility(),
            favoriteAccessibilityValue: isFavorite ? strings.commonOn() : strings.commonOff()
        )
    }

    func createListViewModel(for state: SubtensorSubnetListState, locale: Locale) -> SubtensorSubnetListViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let caption = state.list.map { list in
            strings.stakingSubtensorUiJoinDotFormat(
                strings.stakingSubtensorUiPickerCount(format: list.count),
                sortPhrase(for: state.sort, locale: locale)
            )
        }

        return SubtensorSubnetListViewModel(
            chipTitle: chipTitle(for: state.sort, locale: locale),
            caption: caption,
            isFilterActive: state.filters.isApplied,
            areControlsEnabled: state.list != nil,
            content: createContent(for: state, locale: locale)
        )
    }

    func createRootBarViewModel(annualRate: Decimal?, locale: Locale) -> SubtensorStakeToRootBarViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let subtitle = annualRate.map { rate in
            strings.stakingSubtensorUiPickerRootRateFormat(
                SubtensorApyFormatter.text(for: rate, style: .bare, locale: locale)
            )
        } ?? strings.stakingSubtensorUiPickerRootSubtitle()

        return SubtensorStakeToRootBarViewModel(
            icon: assetIconFactory.createAssetIconViewModel(from: chainAsset.assetDisplayInfo),
            title: strings.stakingSubtensorUiStakeToRoot(),
            subtitle: subtitle
        )
    }

    func createSortSheetViewModel(selected: SubtensorSubnetSort, locale: Locale) -> SubtensorSortSheetViewModel {
        SubtensorSortSheetViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.delegationsSortTitle(),
            options: SubtensorSubnetSort.allCases.map { sortOption(for: $0, locale: locale) },
            selectedIndex: SubtensorSubnetSort.allCases.firstIndex(of: selected)
        )
    }

    func createFiltersViewModel(
        filters: SubtensorSubnetFilters,
        count: Int?,
        isThirtyDayUnavailable: Bool,
        locale: Locale
    ) -> SubtensorSubnetFiltersViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let threshold = formatTokenAmount(
            SubtensorSubnetListBuilder.thinPoolThreshold,
            formatter: compactTokenFormatter,
            locale: locale
        )

        return SubtensorSubnetFiltersViewModel(
            title: strings.walletFiltersTitle(),
            thinPoolsTitle: strings.stakingSubtensorUiPickerHideThin(),
            thinPoolsDetails: strings.stakingSubtensorUiPickerHideThinFormat(threshold),
            aboveAverageTitle: strings.stakingSubtensorUiPickerAboveAverage(),
            aboveAverageDetails: strings.stakingSubtensorUiPickerAboveAverageDetail(),
            filters: filters,
            unavailableText: isThirtyDayUnavailable ? strings.stakingSubtensorUiPickerThirtyDayUnavailable() : nil,
            actionTitle: count.map { strings.stakingSubtensorUiPickerShowCount(format: $0) } ??
                strings.stakingSubtensorUiPickerShow(),
            isLoading: count == nil
        )
    }
}
