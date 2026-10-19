import Foundation
import Foundation_iOS

struct SubtensorSubnetSelectViewModel {
    enum Change {
        case loading
        case value(text: String, isRising: Bool, sparkline: [Double])
        case unavailable(String)
    }

    let subnetRef: SubtensorSubnetRef
    let icon: ImageViewModelProtocol
    let title: String
    let price: String
    let change: Change
    let isFavorite: Bool
    let favoriteAccessibilityLabel: String
    let favoriteAccessibilityValue: String
}

struct SubtensorSubnetListViewModel {
    struct Failure {
        let title: String
        let details: String
        let retryTitle: String?
    }

    enum Content {
        case loading
        case rows(picks: [SubtensorSubnetSelectViewModel], others: [SubtensorSubnetSelectViewModel])
        case empty(String)
        case noMatches(String)
        case failed(Failure)
    }

    let rootIcon: ImageViewModelProtocol
    let chipTitle: String
    let caption: String
    let isFilterActive: Bool
    let areControlsEnabled: Bool
    let content: Content

    var isNoMatches: Bool {
        if case .noMatches = content {
            return true
        }

        return false
    }
}

struct SubtensorSubnetListState {
    let list: SubtensorSubnetList?
    let sort: SubtensorSubnetSort
    let filters: SubtensorSubnetFilters
    let subnetLogos: SubtensorSubnetLogos?
    let stamp: SubtensorBackendStamp?
    let entriesError: Error?
}

protocol SubtensorSubnetViewModelFactoryProtocol {
    func createListViewModel(for state: SubtensorSubnetListState, locale: Locale) -> SubtensorSubnetListViewModel

    func createSortSheetViewModel(selected: SubtensorSubnetSort, locale: Locale) -> SubtensorSortSheetViewModel
}

final class SubtensorSubnetViewModelFactory {
    let chainAsset: ChainAsset
    let iconFactory: SubtensorSubnetIconFactoryProtocol = SubtensorSubnetIconViewModelFactory()
    let rootIcon: ImageViewModelProtocol

    private let tokenFormatter: LocalizableResource<TokenFormatter>
    private let changeFormatter: LocalizableResource<NumberFormatter>

    init(chainAsset: ChainAsset) {
        let balanceFormatterFactory = AssetBalanceFormatterFactory()
        self.chainAsset = chainAsset
        rootIcon = AssetIconViewModelFactory().createAssetIconViewModel(from: chainAsset.assetDisplayInfo)

        tokenFormatter = balanceFormatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo)
        changeFormatter = NumberFormatter.subtensorSignedPercentSingle
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
            return .unavailable(strings.stakingSubtensorUiPickerNoHistory())
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
        subnetLogos: SubtensorSubnetLogos?,
        locale: Locale
    ) -> [SubtensorSubnetSelectViewModel] {
        items.map { createRowViewModel(for: $0, isFavorite: isFavorite, subnetLogos: subnetLogos, locale: locale) }
    }

    func createContent(
        for state: SubtensorSubnetListState,
        locale: Locale
    ) -> SubtensorSubnetListViewModel.Content {
        if let error = state.entriesError {
            return .failed(createFailure(for: error, locale: locale))
        }

        guard let list = state.list else {
            return .loading
        }

        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch list.emptyKind {
        case let .query(query):
            return .noMatches(strings.stakingSubtensorUiPickerEmptyQueryFormat(query))
        case .filters:
            return .empty(strings.stakingSubtensorUiPickerEmpty())
        case .none:
            return .rows(
                picks: createRowViewModels(
                    for: list.picks,
                    isFavorite: true,
                    subnetLogos: state.subnetLogos,
                    locale: locale
                ),
                others: createRowViewModels(
                    for: list.others,
                    isFavorite: false,
                    subnetLogos: state.subnetLogos,
                    locale: locale
                )
            )
        }
    }

    func createFailure(for error: Error, locale: Locale) -> SubtensorSubnetListViewModel.Failure {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let apiError = error as? BittensorApiError
        let isDeviceBound = apiError?.isDeviceBound ?? false
        let allowsUserRetry = apiError?.allowsUserRetry ?? true

        return SubtensorSubnetListViewModel.Failure(
            title: strings.stakingSubtensorUiPickerFetchFailed(),
            details: isDeviceBound
                ? strings.stakingSubtensorUiPickerFetchDeviceDetail()
                : strings.stakingSubtensorUiPickerFetchFailedDetail(),
            retryTitle: allowsUserRetry ? strings.commonTryAgain() : nil
        )
    }

    func sortOption(for sort: SubtensorSubnetSort, locale: Locale) -> SubtensorSortSheetViewModel.Option {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch sort {
        case .sevenDayChange:
            return .init(
                title: strings.stakingSubtensorUiPickerSevenDay(),
                subtitle: strings.stakingSubtensorUiPickerSevenDayDetail()
            )
        case .poolDepth:
            return .init(
                title: strings.stakingSubtensorQuickPoolTitle(),
                subtitle: strings.stakingSubtensorQuickPoolOrder()
            )
        case .age:
            return .init(
                title: strings.stakingSubtensorUiPickerAge(),
                subtitle: strings.stakingSubtensorUiPickerAgeDetail()
            )
        case .apy:
            return .init(
                title: strings.stakingSubtensorUiValidatorSortApy(),
                subtitle: strings.stakingSubtensorUiPickerApyDetail()
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
        subnetLogos: SubtensorSubnetLogos?,
        locale: Locale
    ) -> SubtensorSubnetSelectViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorSubnetSelectViewModel(
            subnetRef: item.ref,
            icon: iconFactory.icon(for: item.subnet, logos: subnetLogos),
            title: SubtensorSubnetNaming.titleWithSymbol(for: item.subnet, locale: locale),
            price: formatTokenAmount(item.subnet.taoPerAlpha, formatter: tokenFormatter, locale: locale),
            change: createChange(for: item.weekly, locale: locale),
            isFavorite: isFavorite,
            favoriteAccessibilityLabel: strings.stakingSubtensorUiPickerFavoriteAccessibility(),
            favoriteAccessibilityValue: isFavorite ? strings.commonOn() : strings.commonOff()
        )
    }

    func createListViewModel(for state: SubtensorSubnetListState, locale: Locale) -> SubtensorSubnetListViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let unknown = strings.stakingSubtensorUiValueUnknown()
        let count = strings.stakingSubtensorQuickCount(
            state.list.map { String($0.count) } ?? unknown,
            state.list.map { String($0.total) } ?? unknown
        )

        let caption = SubtensorFreshnessFormatter.agedHint(for: state.stamp, locale: locale).map {
            strings.stakingSubtensorUiJoinDotFormat(count, $0)
        } ?? count

        return SubtensorSubnetListViewModel(
            rootIcon: rootIcon,
            chipTitle: sortOption(for: state.sort, locale: locale).title,
            caption: caption,
            isFilterActive: state.filters.isApplied,
            areControlsEnabled: state.list != nil,
            content: createContent(for: state, locale: locale)
        )
    }

    func createSortSheetViewModel(selected: SubtensorSubnetSort, locale: Locale) -> SubtensorSortSheetViewModel {
        SubtensorSortSheetViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.delegationsSortTitle(),
            options: SubtensorSubnetSort.allCases.map { sortOption(for: $0, locale: locale) },
            selectedIndex: SubtensorSubnetSort.allCases.firstIndex(of: selected)
        )
    }
}
