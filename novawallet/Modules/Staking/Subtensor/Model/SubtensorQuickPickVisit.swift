import Foundation

/// A visit owns its draw, including across retries while the selected subnet is not yet ready to trade.
final class SubtensorQuickPickVisit {
    enum SelectionError: Error, Equatable {
        case unsupportedOrder
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

    func resolve(_ result: Result<(SubtensorSubnetCatalogue, SubtensorSubnetsInfo), Error>) -> SubtensorStakeTarget? {
        guard isLoading, !isManuallyReplaced else { return nil }
        isLoading = false

        do {
            let (catalogue, info) = try result.get()
            let ref = try selectedRef ?? select(from: catalogue)
            selectedRef = ref

            guard let subnet = info.subnets.first(where: { $0.netuid == ref.netuid }) else {
                throw SelectionError.targetUnavailable
            }
            guard subnet.networkRegisteredAt == ref.registeredAt else {
                throw SelectionError.registrationChanged
            }
            guard info.subtokenEnabled.contains(ref.netuid), let price = info.prices[ref.netuid], price > 0 else {
                throw SelectionError.targetUnavailable
            }
            return .subnet(info: subnet, price: price)
        } catch {
            self.error = error
            return nil
        }
    }
}

private extension SubtensorQuickPickVisit {
    func select(from catalogue: SubtensorSubnetCatalogue) throws -> SubtensorSubnetRef {
        guard order.subnetSort != nil else { throw SelectionError.unsupportedOrder }

        let eligible = catalogue.subnets.filter { $0.taoReserve >= SubtensorSubnetListBuilder.thinPoolThreshold }

        let candidates = eligible.sorted { lhs, rhs in
            switch order {
            case .poolSize where lhs.taoReserve != rhs.taoReserve:
                return lhs.taoReserve > rhs.taoReserve
            case .age where lhs.networkRegisteredAt != rhs.networkRegisteredAt:
                return lhs.networkRegisteredAt < rhs.networkRegisteredAt
            default:
                return lhs.netuid < rhs.netuid
            }
        }.prefix(10)

        guard let ref = candidates.randomElement()?.ref else { throw SelectionError.noCandidates }

        return ref
    }
}
