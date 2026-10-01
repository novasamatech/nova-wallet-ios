import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

struct SubtensorValidatorListInput {
    let directory: SubtensorValidatorDirectory
    let yields: SubtensorAlphaYields?
    let alphaPrice: Balance?
    let isRoot: Bool
    let maxTake: BigRational
    let sort: SubtensorValidatorSort
    let query: String
    let selectedHotkey: AccountId?
    let preselectedHotkey: AccountId?
}

enum SubtensorValidatorEligibility: Equatable {
    case unlisted
    case inactive
    case selectable
}

final class SubtensorValidatorListFactory {
    let chainFormat: ChainFormat

    private let stakeFormatter: LocalizableResource<TokenFormatter>
    private let takeFormatter: LocalizableResource<NumberFormatter>

    init(
        chainFormat: ChainFormat,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.chainFormat = chainFormat
        stakeFormatter = formatterFactory.createCompactTokenFormatter(for: assetDisplayInfo)
        takeFormatter = NumberFormatter.percentSingleHalfEven.localizableResource()
    }
}

extension SubtensorValidatorListFactory {
    static func eligibility(
        of item: SubtensorValidatorDirectoryItem,
        isRoot: Bool,
        maxTake: BigRational
    ) -> SubtensorValidatorEligibility {
        guard
            let status = item.status,
            isRoot || status.hasPermit == true,
            let take = item.take,
            let maxTakeValue = maxTake.decimalValue,
            take <= maxTakeValue else {
            return .unlisted
        }

        return isRoot || status.isActive == true ? .selectable : .inactive
    }

    static func sortOptions(isRoot: Bool, yields: SubtensorAlphaYields?) -> [SubtensorValidatorSort] {
        ratesShown(isRoot: isRoot, yields: yields) ? [.apy, .totalStaked, .name] : [.totalStaked, .name]
    }

    static func appliedSort(
        _ requested: SubtensorValidatorSort,
        isRoot: Bool,
        yields: SubtensorAlphaYields?
    ) -> SubtensorValidatorSort {
        sortOptions(isRoot: isRoot, yields: yields).contains(requested) ? requested : .totalStaked
    }

    static func preselectedHotkey(
        _ current: AccountId?,
        in directory: SubtensorValidatorDirectory,
        isRoot: Bool,
        maxTake: BigRational
    ) -> AccountId? {
        selectableItem(for: current, in: directory, isRoot: isRoot, maxTake: maxTake)?.hotkey
    }

    static func selectableItem(
        for hotkey: AccountId?,
        in directory: SubtensorValidatorDirectory?,
        isRoot: Bool,
        maxTake: BigRational
    ) -> SubtensorValidatorDirectoryItem? {
        directory?.items.first { item in
            item.hotkey == hotkey && eligibility(of: item, isRoot: isRoot, maxTake: maxTake) == .selectable
        }
    }
}

extension SubtensorValidatorListFactory {
    func createListViewModel(
        for input: SubtensorValidatorListInput,
        locale: Locale
    ) -> SubtensorValidatorListViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let sort = Self.appliedSort(input.sort, isRoot: input.isRoot, yields: input.yields)
        let ratesShown = Self.ratesShown(isRoot: input.isRoot, yields: input.yields)

        let entries = createEntries(for: input, unknown: strings.stakingSubtensorUiValueUnknown())
        let hidesUnrated = ratesShown && entries.contains { $0.isSelectable && $0.rate != nil }
        let keptHotkeys = [input.selectedHotkey, input.preselectedHotkey]
        let listed = entries.filter { entry in
            keptHotkeys.contains(entry.item.hotkey) || (entry.isSelectable && (entry.rate != nil || !hidesUnrated))
        }
        let matching = listed
            .filter { matches($0, query: input.query) }
            .sorted { Self.isOrderedBefore($0, $1, sort: sort) }

        let selected = listed.first { $0.isSelectable && $0.item.hotkey == input.selectedHotkey }

        let rowContext = RowContext(
            input: input,
            locale: locale,
            stakeFormatter: stakeFormatter.value(for: locale),
            takeFormatter: takeFormatter.value(for: locale)
        )

        return SubtensorValidatorListViewModel(
            rows: matching.map { createRow(for: $0, context: rowContext) },
            countTitle: strings.stakingSubtensorUiValidatorCountFormat(matching.count),
            sortTitle: createSortTitle(
                for: sort,
                ratesShown: ratesShown,
                locale: locale
            ),
            emptyText: createEmptyText(
                hasListed: !listed.isEmpty,
                hasMatching: !matching.isEmpty,
                input: input,
                locale: locale
            ),
            selectTitle: selected.map { strings.stakingSubtensorUiValidatorSelectFormat($0.title) } ??
                strings.stakingSubtensorSelectValidator(),
            canSelect: selected != nil
        )
    }

    func createLoadingViewModel(isRoot: Bool, locale: Locale) -> SubtensorValidatorListHeaderViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorValidatorListHeaderViewModel(
            countTitle: strings.stakingSubtensorUiValidatorLoadingCount(),
            sortTitle: createSortTitle(for: isRoot ? .totalStaked : .apy, ratesShown: !isRoot, locale: locale),
            selectTitle: strings.stakingSubtensorSelectValidator()
        )
    }

    func createErrorViewModel(for error: Error, locale: Locale) -> SubtensorValidatorErrorViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let isDeviceBound = (error as? BittensorApiError)?.isDeviceBound ?? false

        return SubtensorValidatorErrorViewModel(
            title: strings.stakingSubtensorUiValidatorFetchFailed(),
            details: isDeviceBound
                ? strings.stakingSubtensorUiValidatorFetchDeviceDetail()
                : strings.stakingSubtensorUiValidatorFetchFailedDetail(),
            retryTitle: isDeviceBound ? nil : strings.commonTryAgain(),
            selectTitle: strings.stakingSubtensorSelectValidator()
        )
    }

    func createSortSheetViewModel(
        options: [SubtensorValidatorSort],
        selected: SubtensorValidatorSort,
        locale: Locale
    ) -> SubtensorSortSheetViewModel {
        SubtensorSortSheetViewModel(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.delegationsSortTitle(),
            options: options.map { .init(title: createSortOptionTitle(for: $0, locale: locale), subtitle: nil) },
            selectedIndex: options.firstIndex(of: selected)
        )
    }
}

private extension SubtensorValidatorListFactory {
    struct Entry {
        let item: SubtensorValidatorDirectoryItem
        let isSelectable: Bool
        let title: String
        let address: String?
        let rate: Decimal?
    }

    struct RowContext {
        let input: SubtensorValidatorListInput
        let locale: Locale
        let stakeFormatter: TokenFormatter
        let takeFormatter: NumberFormatter
    }

    static func ratesShown(isRoot: Bool, yields: SubtensorAlphaYields?) -> Bool {
        !isRoot && yields?.stamp.freshness == .fresh
    }

    static func compareStakes(_ lhs: BigRational?, _ rhs: BigRational?) -> ComparisonResult {
        guard let lhs else {
            return rhs == nil ? .orderedSame : .orderedAscending
        }

        guard let rhs else {
            return .orderedDescending
        }

        let left = lhs.numerator * rhs.denominator
        let right = rhs.numerator * lhs.denominator

        if left == right {
            return .orderedSame
        }

        return left < right ? .orderedAscending : .orderedDescending
    }

    static func compareRates(_ lhs: Decimal?, _ rhs: Decimal?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return lhs == rhs ? .orderedSame : (lhs < rhs ? .orderedAscending : .orderedDescending)
        case (.some, .none):
            return .orderedDescending
        case (.none, .some):
            return .orderedAscending
        case (.none, .none):
            return .orderedSame
        }
    }

    static func isOrderedBefore(_ lhs: Entry, _ rhs: Entry, sort: SubtensorValidatorSort) -> Bool {
        if lhs.isSelectable != rhs.isSelectable {
            return lhs.isSelectable
        }

        let orders: [ComparisonResult]

        switch sort {
        case .apy:
            orders = [
                compareRates(lhs.rate, rhs.rate),
                compareStakes(lhs.item.reportedStake, rhs.item.reportedStake)
            ]
        case .totalStaked:
            orders = [compareStakes(lhs.item.reportedStake, rhs.item.reportedStake)]
        case .name:
            orders = []
        }

        if let order = orders.first(where: { $0 != .orderedSame }) {
            return order == .orderedDescending
        }

        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    func createEntries(for input: SubtensorValidatorListInput, unknown: String) -> [Entry] {
        input.directory.items.compactMap { item in
            let eligibility = Self.eligibility(of: item, isRoot: input.isRoot, maxTake: input.maxTake)

            guard eligibility != .unlisted else {
                return nil
            }

            let address = try? item.hotkey.toAddress(using: chainFormat)

            return Entry(
                item: item,
                isSelectable: eligibility == .selectable,
                title: item.name ?? address?.mediumTruncated ?? unknown,
                address: address,
                rate: input.isRoot ? nil : SubtensorAlphaApyFormatter.annualRate(for: item.hotkey, in: input.yields)
            )
        }
    }

    func matches(_ entry: Entry, query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return true
        }

        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        return [entry.item.name, entry.address].contains { value in
            value?.range(of: trimmedQuery, options: options) != nil
        }
    }

    func taoStake(for item: SubtensorValidatorDirectoryItem, input: SubtensorValidatorListInput) -> Decimal? {
        guard let stake = item.reportedStake else {
            return nil
        }

        guard !input.isRoot else {
            return stake.decimalValue
        }

        guard let alphaPrice = input.alphaPrice else {
            return nil
        }

        return BigRational(
            numerator: stake.numerator * alphaPrice,
            denominator: stake.denominator * SubtensorStakingPallet.alphaPriceScale
        ).decimalValue
    }

    func createRow(
        for entry: Entry,
        context: RowContext
    ) -> SubtensorValidatorRowViewModel {
        let strings = R.string(preferredLanguages: context.locale.rLanguages).localizable
        let unknown = strings.stakingSubtensorUiValueUnknown()

        let stakeText = taoStake(for: entry.item, input: context.input).flatMap {
            context.stakeFormatter.stringFromDecimal($0)
        } ?? unknown

        let takeText = entry.item.take.flatMap { context.takeFormatter.stringFromDecimal($0) } ?? unknown

        let trailing: SubtensorValidatorRowViewModel.Trailing

        if !entry.isSelectable {
            trailing = .inactive(strings.stakingNominatorStatusInactive())
        } else if let rate = entry.rate {
            trailing = .rate(SubtensorApyFormatter.text(for: rate, style: .column, locale: context.locale))
        } else {
            trailing = .none
        }

        return SubtensorValidatorRowViewModel(
            hotkey: entry.item.hotkey,
            title: entry.title,
            subtitle: strings.stakingSubtensorUiValidatorRowSubtitleFormat(stakeText, takeText),
            trailing: trailing,
            isSelected: entry.item.hotkey == context.input.selectedHotkey,
            isSelectable: entry.isSelectable
        )
    }

    func createSortOptionTitle(for sort: SubtensorValidatorSort, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch sort {
        case .apy:
            return strings.stakingSubtensorUiValidatorSortApy()
        case .totalStaked:
            return strings.stakingMainTotalStakedTitle()
        case .name:
            return strings.commonName()
        }
    }

    func createSortTitle(for sort: SubtensorValidatorSort, ratesShown: Bool, locale: Locale) -> String {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let sortTitle = createSortOptionTitle(for: sort, locale: locale).uppercased(with: locale)

        return ratesShown
            ? strings.stakingSubtensorUiValidatorHeaderRatesFormat(sortTitle)
            : strings.stakingSubtensorUiValidatorHeaderSortFormat(sortTitle)
    }

    func createEmptyText(
        hasListed: Bool,
        hasMatching: Bool,
        input: SubtensorValidatorListInput,
        locale: Locale
    ) -> String? {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        guard hasListed else {
            return strings.stakingSubtensorUiValidatorNoData()
        }

        guard hasMatching else {
            let query = input.query.trimmingCharacters(in: .whitespacesAndNewlines)

            return strings.stakingSubtensorUiValidatorSearchEmptyFormat(query)
        }

        return nil
    }
}
