import Foundation

/// A visit owns a draw, including when the selected subnet is not yet ready to trade.
final class SubtensorQuickPickVisit {
    let order: SubtensorQuickPickOrder
    let selector: SubtensorQuickPickSelector
    private(set) var selectedRef: SubtensorSubnetRef?
    private(set) var isManuallyReplaced = false
    private(set) var generation = 0
    private(set) var isLoading = false
    private(set) var error: Error?

    init(order: SubtensorQuickPickOrder, selector: SubtensorQuickPickSelector = .init()) {
        self.order = order
        self.selector = selector
    }

    func beginRequest() -> Int {
        generation += 1
        isLoading = true
        error = nil
        return generation
    }

    func replaceManually() {
        generation += 1
        isManuallyReplaced = true
        isLoading = false
        error = nil
    }

    func resolve(_ result: Result<SubtensorSubnetsInfo, Error>, generation: Int) -> SubtensorStakeTarget? {
        guard self.generation == generation, isLoading, !isManuallyReplaced else { return nil }
        isLoading = false

        do {
            let info = try result.get()
            guard info.isComplete else { throw SubtensorQuickPickSelector.SelectionError.incompleteSnapshot }
            let ref: SubtensorSubnetRef
            if let selectedRef {
                ref = selectedRef
            } else {
                ref = try selector.select(from: info, order: order)
                selectedRef = ref
            }

            guard let subnet = info.subnets.first(where: { $0.netuid == ref.netuid }) else {
                throw SubtensorQuickPickSelector.SelectionError.targetUnavailable
            }
            guard subnet.networkRegisteredAt == ref.registeredAt else {
                throw SubtensorQuickPickSelector.SelectionError.registrationChanged
            }
            guard info.subtokenEnabled.contains(ref.netuid), let price = info.prices[ref.netuid], price > 0 else {
                throw SubtensorQuickPickSelector.SelectionError.targetUnavailable
            }
            return .subnet(info: subnet, price: price)
        } catch {
            self.error = error
            return nil
        }
    }
}
