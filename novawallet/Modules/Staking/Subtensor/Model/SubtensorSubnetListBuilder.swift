import BigInt
import Foundation

struct SubtensorSubnetListEntry: Equatable {
    let subnet: SubtensorCatalogueSubnet
    let target: SubtensorStakeTarget
}

struct SubtensorSubnetListItem: Equatable {
    let subnet: SubtensorCatalogueSubnet
    let target: SubtensorStakeTarget
    let weekly: SubtensorPriceData<SubtensorWeeklyPriceSummary>?
    let monthly: SubtensorPriceData<SubtensorMonthlyPriceMetrics>?
    let ageBlocks: UInt64?

    var ref: SubtensorSubnetRef {
        subnet.ref
    }
}

struct SubtensorSubnetList: Equatable {
    enum EmptyKind: Equatable {
        case query(String)
        case filters
    }

    let picks: [SubtensorSubnetListItem]
    let others: [SubtensorSubnetListItem]
    let emptyKind: EmptyKind?

    var count: Int {
        picks.count + others.count
    }
}

struct SubtensorSubnetListBuilder {
    static let thinPoolThreshold = BigUInt(2_000_000_000_000)

    let entries: [SubtensorSubnetListEntry]
    let weekly: [SubtensorSubnetRef: SubtensorPriceData<SubtensorWeeklyPriceSummary>]?
    let monthly: [SubtensorSubnetRef: SubtensorPriceData<SubtensorMonthlyPriceMetrics>]?
    let ageBlocks: [UInt16: UInt64]
    let favourites: Set<SubtensorSubnetRef>
    let locale: Locale

    func build(
        query: String,
        sort: SubtensorSubnetSort,
        filters: SubtensorSubnetFilters
    ) -> SubtensorSubnetList {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        let items = entries
            .map(createItem)
            .filter { matches($0, query: trimmedQuery) && passes($0, filters: filters) }

        let titles = Dictionary(
            items.map { ($0.ref, SubtensorSubnetNaming.title(for: $0.subnet, locale: locale)) },
            uniquingKeysWith: { first, _ in first }
        )

        let sorted = items.sorted { lhs, rhs in
            isOrderedBefore(lhs, rhs, sort: sort, titles: titles)
        }

        let picks = sorted.filter { favourites.contains($0.ref) }
        let others = sorted.filter { !favourites.contains($0.ref) }

        let emptyKind: SubtensorSubnetList.EmptyKind? = sorted.isEmpty
            ? (trimmedQuery.isEmpty ? .filters : .query(trimmedQuery))
            : nil

        return SubtensorSubnetList(picks: picks, others: others, emptyKind: emptyKind)
    }

    static func entries(
        from catalogue: SubtensorSubnetCatalogue,
        subnetsInfo: SubtensorSubnetsInfo
    ) -> [SubtensorSubnetListEntry] {
        let chainSubnets = Dictionary(
            subnetsInfo.subnets.map { ($0.netuid, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return catalogue.subnets.compactMap { subnet in
            guard
                let info = chainSubnets[subnet.netuid],
                info.networkRegisteredAt == subnet.networkRegisteredAt,
                subnetsInfo.subtokenEnabled.contains(subnet.netuid),
                let price = subnetsInfo.prices[subnet.netuid] else {
                return nil
            }

            return SubtensorSubnetListEntry(subnet: subnet, target: .subnet(info: info, price: price))
        }
    }
}

private extension SubtensorSubnetListBuilder {
    enum ChangeRank {
        case value(Decimal)
        case unavailable
        case notListed
    }

    func createItem(from entry: SubtensorSubnetListEntry) -> SubtensorSubnetListItem {
        let ref = entry.subnet.ref

        return SubtensorSubnetListItem(
            subnet: entry.subnet,
            target: entry.target,
            weekly: weekly.map { $0[ref] ?? .unavailable },
            monthly: monthly.map { $0[ref] ?? .unavailable },
            ageBlocks: ageBlocks[entry.subnet.netuid]
        )
    }

    func matches(_ item: SubtensorSubnetListItem, query: String) -> Bool {
        guard !query.isEmpty else {
            return true
        }

        let name = item.subnet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let symbol = item.subnet.symbol.trimmingCharacters(in: .whitespacesAndNewlines)

        return name.localizedCaseInsensitiveContains(query) ||
            symbol.localizedCaseInsensitiveContains(query) ||
            String(item.subnet.netuid) == query
    }

    func passes(_ item: SubtensorSubnetListItem, filters: SubtensorSubnetFilters) -> Bool {
        if filters.hideThinPools, item.subnet.taoReserve < Self.thinPoolThreshold {
            return false
        }

        if filters.onlyAboveThirtyDayAverage {
            guard let mean = item.monthly?.availableValue?.meanTaoPerAlpha else {
                return false
            }

            let price = item.subnet.taoPerAlpha.decimal(precision: UInt16(SubtensorSubnetCatalogueService.atomicScale))

            return price > mean
        }

        return true
    }

    func isOrderedBefore(
        _ lhs: SubtensorSubnetListItem,
        _ rhs: SubtensorSubnetListItem,
        sort: SubtensorSubnetSort,
        titles: [SubtensorSubnetRef: String]
    ) -> Bool {
        let primary: Bool?

        switch sort {
        case .sevenDayChange:
            primary = weekly != nil ? compare(weeklyRank(of: lhs), weeklyRank(of: rhs)) : nil
        case .thirtyDayChange:
            primary = monthly != nil ? compare(monthlyRank(of: lhs), monthlyRank(of: rhs)) : nil
        case .poolDepth:
            primary = lhs.subnet.taoReserve != rhs.subnet.taoReserve
                ? lhs.subnet.taoReserve > rhs.subnet.taoReserve
                : nil
        case .age:
            primary = compare(age: lhs.ageBlocks, rhs.ageBlocks)
        case .name:
            primary = nil
        }

        return primary ?? isNameOrdered(lhs, rhs, titles: titles)
    }

    func isNameOrdered(
        _ lhs: SubtensorSubnetListItem,
        _ rhs: SubtensorSubnetListItem,
        titles: [SubtensorSubnetRef: String]
    ) -> Bool {
        let lhsTitle = titles[lhs.ref] ?? ""
        let rhsTitle = titles[rhs.ref] ?? ""

        switch lhsTitle.localizedStandardCompare(rhsTitle) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            return lhs.subnet.netuid < rhs.subnet.netuid
        }
    }

    func weeklyRank(of item: SubtensorSubnetListItem) -> ChangeRank {
        switch item.weekly {
        case let .available(summary):
            return .value(summary.change)
        case .notListed:
            return .notListed
        case .unavailable, .none:
            return .unavailable
        }
    }

    func monthlyRank(of item: SubtensorSubnetListItem) -> ChangeRank {
        switch item.monthly {
        case let .available(metrics):
            return metrics.changeInTao.map { .value($0) } ?? .unavailable
        case .notListed:
            return .notListed
        case .unavailable, .none:
            return .unavailable
        }
    }

    func compare(_ lhs: ChangeRank, _ rhs: ChangeRank) -> Bool? {
        switch (lhs, rhs) {
        case let (.value(lhsValue), .value(rhsValue)):
            return lhsValue != rhsValue ? lhsValue > rhsValue : nil
        case (.value, _):
            return true
        case (_, .value):
            return false
        case (.unavailable, .notListed):
            return true
        case (.notListed, .unavailable):
            return false
        case (.unavailable, .unavailable), (.notListed, .notListed):
            return nil
        }
    }

    func compare(age lhs: UInt64?, _ rhs: UInt64?) -> Bool? {
        switch (lhs, rhs) {
        case let (.some(lhsAge), .some(rhsAge)):
            return lhsAge != rhsAge ? lhsAge > rhsAge : nil
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return nil
        }
    }
}
