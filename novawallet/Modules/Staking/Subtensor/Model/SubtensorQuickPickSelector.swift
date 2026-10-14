import Foundation

struct SubtensorQuickPickSelector {
    enum SelectionError: Error, Equatable {
        case unsupportedOrder
        case noCandidates
        case invalidIndex
        case targetUnavailable
        case registrationChanged
    }

    let randomIndex: (Range<Int>) -> Int

    init(randomIndex: @escaping (Range<Int>) -> Int = { Int.random(in: $0) }) {
        self.randomIndex = randomIndex
    }

    func candidates(
        from catalogue: SubtensorSubnetCatalogue,
        order: SubtensorQuickPickOrder
    ) throws -> [SubtensorSubnetRef] {
        guard order.subnetSort != nil else { throw SelectionError.unsupportedOrder }

        let eligible = catalogue.subnets.filter { $0.taoReserve >= SubtensorSubnetListBuilder.thinPoolThreshold }

        return eligible.sorted { lhs, rhs in
            switch order {
            case .poolSize where lhs.taoReserve != rhs.taoReserve:
                return lhs.taoReserve > rhs.taoReserve
            case .age where lhs.networkRegisteredAt != rhs.networkRegisteredAt:
                return lhs.networkRegisteredAt < rhs.networkRegisteredAt
            default:
                return lhs.netuid < rhs.netuid
            }
        }.prefix(10).map(\.ref)
    }

    func select(from catalogue: SubtensorSubnetCatalogue, order: SubtensorQuickPickOrder) throws -> SubtensorSubnetRef {
        let candidates = try candidates(from: catalogue, order: order)
        guard !candidates.isEmpty else { throw SelectionError.noCandidates }
        let index = randomIndex(0 ..< candidates.count)
        guard candidates.indices.contains(index) else { throw SelectionError.invalidIndex }
        return candidates[index]
    }
}
