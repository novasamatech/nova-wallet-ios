import Foundation

struct SubtensorQuickPickSelector {
    enum SelectionError: Error, Equatable {
        case unsupportedOrder
        case incompleteSnapshot
        case noCandidates
        case invalidIndex
        case targetUnavailable
        case registrationChanged
    }

    let randomIndex: (Range<Int>) -> Int

    init(randomIndex: @escaping (Range<Int>) -> Int = { Int.random(in: $0) }) {
        self.randomIndex = randomIndex
    }

    func candidates(from info: SubtensorSubnetsInfo, order: SubtensorQuickPickOrder) throws -> [SubtensorSubnetRef] {
        guard order.subnetSort != nil else { throw SelectionError.unsupportedOrder }
        guard info.isComplete else { throw SelectionError.incompleteSnapshot }

        let eligible = info.subnets.filter {
            $0.netuid != SubtensorStakingPallet.rootNetuid &&
                $0.taoIn >= SubtensorSubnetListBuilder.thinPoolThreshold
        }

        return eligible.sorted { lhs, rhs in
            switch order {
            case .poolSize where lhs.taoIn != rhs.taoIn:
                return lhs.taoIn > rhs.taoIn
            case .age where lhs.networkRegisteredAt != rhs.networkRegisteredAt:
                return lhs.networkRegisteredAt < rhs.networkRegisteredAt
            default:
                return lhs.netuid < rhs.netuid
            }
        }.prefix(10).map { SubtensorSubnetRef(netuid: $0.netuid, registeredAt: $0.networkRegisteredAt) }
    }

    func select(from info: SubtensorSubnetsInfo, order: SubtensorQuickPickOrder) throws -> SubtensorSubnetRef {
        let candidates = try candidates(from: info, order: order)
        guard !candidates.isEmpty else { throw SelectionError.noCandidates }
        let index = randomIndex(0 ..< candidates.count)
        guard candidates.indices.contains(index) else { throw SelectionError.invalidIndex }
        return candidates[index]
    }
}
