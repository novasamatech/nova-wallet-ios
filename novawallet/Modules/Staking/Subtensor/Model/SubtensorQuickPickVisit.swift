import Foundation

struct SubtensorQuickPickSnapshot {
    let ref: SubtensorSubnetRef
    let info: SubtensorSubnetsInfo
}

/// A visit owns its draw, including across retries while the selected subnet is not yet ready to trade.
final class SubtensorQuickPickVisit {
    enum SelectionError: Error, Equatable {
        case noCandidates
        case targetUnavailable
        case registrationChanged
    }

    let order: SubtensorQuickPickOrder
    private(set) var selectedRef: SubtensorSubnetRef?
    private(set) var isManuallyReplaced = false
    private(set) var isLoading = false
    private(set) var error: Error?

    init(order: SubtensorQuickPickOrder) {
        self.order = order
    }

    func beginRequest() {
        isLoading = true
        error = nil
    }

    func replaceManually() {
        isManuallyReplaced = true
        isLoading = false
        error = nil
    }

    func resolve(_ result: Result<SubtensorQuickPickSnapshot, Error>) -> SubtensorStakeTarget? {
        guard isLoading, !isManuallyReplaced else { return nil }
        isLoading = false

        do {
            let snapshot = try result.get()
            let ref = snapshot.ref
            selectedRef = ref

            guard let subnet = snapshot.info.subnets.first(where: { $0.netuid == ref.netuid }) else {
                selectedRef = nil
                throw SelectionError.targetUnavailable
            }
            guard subnet.networkRegisteredAt == ref.registeredAt else {
                selectedRef = nil
                throw SelectionError.registrationChanged
            }
            guard
                snapshot.info.subtokenEnabled.contains(ref.netuid),
                let price = snapshot.info.prices[ref.netuid], price > 0 else {
                throw SelectionError.targetUnavailable
            }
            return .subnet(info: subnet, price: price)
        } catch {
            self.error = error
            return nil
        }
    }
}

extension SubtensorQuickPickVisit {
    static func select(
        order: SubtensorQuickPickOrder,
        from catalogue: SubtensorSubnetCatalogue,
        apy: [UInt16: Decimal]
    ) throws -> SubtensorSubnetRef {
        let eligible = catalogue.subnets.filter {
            $0.taoReserve >= SubtensorSubnetListBuilder.thinPoolThreshold && (order != .apy || apy[$0.netuid] != nil)
        }

        let candidates = eligible.sorted { lhs, rhs in
            switch order {
            case .poolSize where lhs.taoReserve != rhs.taoReserve:
                return lhs.taoReserve > rhs.taoReserve
            case .age where lhs.networkRegisteredAt != rhs.networkRegisteredAt:
                return lhs.networkRegisteredAt < rhs.networkRegisteredAt
            case .apy where apy[lhs.netuid] != apy[rhs.netuid]:
                return (apy[lhs.netuid] ?? 0) > (apy[rhs.netuid] ?? 0)
            default:
                return lhs.netuid < rhs.netuid
            }
        }.prefix(10)

        guard let ref = candidates.randomElement()?.ref else { throw SelectionError.noCandidates }

        return ref
    }
}
