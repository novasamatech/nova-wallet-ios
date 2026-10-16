import Foundation
import BigInt
import Foundation_iOS
import SubstrateSdk

struct SubtensorValidatorListInput {
    let directory: SubtensorValidatorDirectory
    let yields: SubtensorAlphaYields?
    let alphaPrice: Balance?
    let isRoot: Bool
    let sort: SubtensorValidatorSort
    let query: String
    let selectedHotkey: AccountId?
    let preselectedHotkey: AccountId?
    let keptHotkeys: Set<AccountId>
    let recommendedHotkeys: Set<AccountId>?
}

final class SubtensorValidatorListFactory {
    let chainFormat: ChainFormat

    private let stakeFormatter: LocalizableResource<TokenFormatter>
    private let takeFormatter: LocalizableResource<NumberFormatter>
    private let iconGenerator = PolkadotIconGenerator()

    init(
        chainFormat: ChainFormat,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.chainFormat = chainFormat
        stakeFormatter = formatterFactory.createCompactTokenFormatter(for: assetDisplayInfo)
        takeFormatter = NumberFormatter.subtensorPercentSingleHalfEven
    }
}

extension SubtensorValidatorListFactory {
    func createListViewModel(
        for input: SubtensorValidatorListInput,
        locale: Locale
    ) -> SubtensorValidatorListViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let sort = input.sort
        let ratesShown = Self.ratesShown(yields: input.yields)

        let listed = createEntries(for: input, unknown: strings.stakingSubtensorUiValueUnknown())
        let pinned = input.preselectedHotkey
        let matching = listed.filter { matches($0, query: input.query) }.sorted {
            if ($0.item.hotkey == pinned) != ($1.item.hotkey == pinned) { return $0.item.hotkey == pinned }
            return Self.isOrderedBefore($0, $1, sort: sort)
        }

        let selected = listed.first { $0.item.hotkey == input.selectedHotkey }

        let total = input.directory.isPartial ? "—" : String(input.directory.items.count)

        let rowContext = RowContext(
            input: input,
            locale: locale,
            stakeFormatter: stakeFormatter.value(for: locale),
            takeFormatter: takeFormatter.value(for: locale)
        )

        return SubtensorValidatorListViewModel(
            rows: matching.map { createRow(for: $0, context: rowContext) },
            countTitle: strings.stakingSubtensorV22CountFormat(String(matching.count), total),
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

    func createLoadingViewModel(
        yields: SubtensorAlphaYields?,
        sort: SubtensorValidatorSort,
        locale: Locale
    ) -> SubtensorValidatorListHeaderViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return SubtensorValidatorListHeaderViewModel(
            countTitle: strings.stakingSubtensorV22CountFormat("—", "—"),
            sortTitle: createSortTitle(for: sort, ratesShown: Self.ratesShown(yields: yields), locale: locale),
            selectTitle: strings.stakingSubtensorSelectValidator()
        )
    }

    func createErrorViewModel(for error: Error, locale: Locale) -> SubtensorValidatorErrorViewModel {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let apiError = error as? BittensorApiError
        let isDeviceBound = apiError?.isDeviceBound ?? false
        let allowsUserRetry = apiError?.allowsUserRetry ?? true

        return SubtensorValidatorErrorViewModel(
            title: strings.stakingSubtensorUiValidatorFetchFailed(),
            details: isDeviceBound
                ? strings.stakingSubtensorUiValidatorFetchDeviceDetail()
                : strings.stakingSubtensorUiValidatorFetchFailedDetail(),
            retryTitle: allowsUserRetry ? strings.commonTryAgain() : nil,
            selectTitle: strings.stakingSubtensorSelectValidator()
        )
    }
}

private extension SubtensorValidatorListFactory {
    struct Entry {
        let item: SubtensorValidatorDirectoryItem
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

    static func ratesShown(yields: SubtensorAlphaYields?) -> Bool {
        yields?.stamp.freshness == .fresh
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

    static func isOrderedBefore(_ lhs: Entry, _ rhs: Entry, sort: SubtensorValidatorSort) -> Bool {
        if sort == .apy, lhs.rate != rhs.rate {
            guard let left = lhs.rate, let right = rhs.rate else { return lhs.rate != nil }
            return left > right
        }

        let stakeOrder = sort == .name ? .orderedSame : compareStakes(lhs.item.reportedStake, rhs.item.reportedStake)

        if stakeOrder != .orderedSame {
            return stakeOrder == .orderedDescending
        }

        let nameOrder = lhs.title.localizedStandardCompare(rhs.title)
        return nameOrder == .orderedSame ? lhs.item.hotkey
            .lexicographicallyPrecedes(rhs.item.hotkey) : nameOrder == .orderedAscending
    }

    func createEntries(for input: SubtensorValidatorListInput, unknown: String) -> [Entry] {
        let kept = input.keptHotkeys.union([input.selectedHotkey, input.preselectedHotkey].compactMap { $0 })

        return input.directory.items.filter { item in
            input.recommendedHotkeys.map { $0.contains(item.hotkey) || kept.contains(item.hotkey) } ?? true
        }.map { item in
            let address = try? item.hotkey.toAddress(using: chainFormat)

            return Entry(
                item: item,
                title: item.name ?? address?.mediumTruncated ?? unknown,
                address: address,
                rate: SubtensorAlphaApyFormatter.annualRate(for: item.hotkey, in: input.yields)
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
        guard input.directory.listStamp?.freshness == .fresh else {
            return nil
        }

        return SubtensorValidatorInfoViewModelFactory.taoStake(
            for: item,
            isRoot: input.isRoot,
            alphaPrice: input.alphaPrice
        )
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

        if entry.rate != nil || (context.input.isRoot && Self.ratesShown(yields: context.input.yields)) {
            trailing = .rate(SubtensorApyFormatter.text(for: entry.rate, style: .bare, locale: context.locale))
        } else {
            trailing = .none
        }

        return SubtensorValidatorRowViewModel(
            hotkey: entry.item.hotkey,
            icon: try? iconGenerator.generateFromAccountId(entry.item.hotkey),
            title: entry.title,
            subtitle: strings.stakingSubtensorUiValidatorRowSubtitleFormat(stakeText, takeText),
            trailing: trailing,
            isSelected: entry.item.hotkey == context.input.selectedHotkey
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
