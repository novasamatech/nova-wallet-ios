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
    var previousOrder: [SubtensorSubnetRef] = []
    let favourites: Set<SubtensorSubnetRef>
    let locale: Locale

    func build(
        query: String,
        sort: SubtensorSubnetSort,
        filters: SubtensorSubnetFilters
    ) -> SubtensorSubnetList {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = orderedItems(sort: sort).filter {
            matches($0, query: trimmedQuery) && passes($0, filters: filters)
        }
        let picks = sorted.filter { favourites.contains($0.ref) }
        let others = sorted.filter { !favourites.contains($0.ref) }
        let emptyKind: SubtensorSubnetList.EmptyKind? = sorted.isEmpty
            ? (trimmedQuery.isEmpty ? .filters : .query(trimmedQuery)) : nil
        return SubtensorSubnetList(picks: picks, others: others, emptyKind: emptyKind)
    }

    func orderedRefs(sort: SubtensorSubnetSort) -> [SubtensorSubnetRef] {
        orderedItems(sort: sort).map(\.ref)
    }

    private func orderedItems(sort: SubtensorSubnetSort) -> [SubtensorSubnetListItem] {
        let items = entries.map(createItem)
        let known = Set(previousOrder)
        let missing: [SubtensorSubnetRef] = items.map(\.ref).filter { !known.contains($0) }
        let appended = missing.sorted { lhs, rhs in
            if lhs.netuid != rhs.netuid { return lhs.netuid < rhs.netuid }
            return lhs.registeredAt < rhs.registeredAt
        }
        let ranks = Dictionary(
            (previousOrder + appended).enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let titles = Dictionary(
            items.map { ($0.ref, SubtensorSubnetNaming.title(for: $0.subnet, locale: locale)) },
            uniquingKeysWith: { first, _ in first }
        )
        return items.sorted { lhs, rhs in
            isOrderedBefore(lhs, rhs, sort: sort, titles: titles) ?? ((ranks[lhs.ref] ?? 0) < (ranks[rhs.ref] ?? 0))
        }
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
    func createItem(from entry: SubtensorSubnetListEntry) -> SubtensorSubnetListItem {
        let ref = entry.subnet.ref

        return SubtensorSubnetListItem(
            subnet: entry.subnet,
            target: entry.target,
            weekly: weekly?[ref]
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
        if filters.hideThinPools, !favourites.contains(item.ref),
           item.subnet.taoReserve < Self.thinPoolThreshold {
            return false
        }

        return true
    }

    func isOrderedBefore(
        _ lhs: SubtensorSubnetListItem,
        _ rhs: SubtensorSubnetListItem,
        sort: SubtensorSubnetSort,
        titles: [SubtensorSubnetRef: String]
    ) -> Bool? {
        switch sort {
        case .sevenDayChange:
            return compareOptional(weeklyValue(of: lhs), weeklyValue(of: rhs), ascending: false)
        case .poolDepth:
            return compare(lhs.subnet.taoReserve, rhs.subnet.taoReserve, ascending: false)
        case .age:
            return compare(lhs.subnet.networkRegisteredAt, rhs.subnet.networkRegisteredAt, ascending: true)
        case .name:
            switch (titles[lhs.ref] ?? "").localizedStandardCompare(titles[rhs.ref] ?? "") {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return nil
            }
        case .apy:
            return nil
        }
    }

    func compare<Value: Comparable>(_ lhs: Value, _ rhs: Value, ascending: Bool) -> Bool? {
        lhs == rhs ? nil : (ascending ? lhs < rhs : lhs > rhs)
    }

    func compareOptional<Value: Comparable>(_ lhs: Value?, _ rhs: Value?, ascending: Bool) -> Bool? {
        switch (lhs, rhs) {
        case let (.some(left), .some(right)): return compare(left, right, ascending: ascending)
        case (.some, .none): return true
        case (.none, .some): return false
        case (.none, .none): return nil
        }
    }

    func weeklyValue(of item: SubtensorSubnetListItem) -> Decimal? {
        guard case let .available(summary) = item.weekly else { return nil }
        return summary.change
    }
}
