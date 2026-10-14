import Foundation
import Operation_iOS

final class SubtensorCataloguePricingTracker {
    struct Valuation: Equatable {
        let stake: Balance
        let isFullyPriced: Bool?
    }

    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var catalogue: Result<SubtensorSubnetCatalogue, Error>?
    private let callStore = CancellableCallStore()

    init(
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.catalogueService = catalogueService
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func reset() {
        catalogue = nil
    }

    func cancel() {
        callStore.cancel()
    }

    func valuation(of state: Multistaking.SubtensorStakingState) -> Valuation {
        let portfolio = SubtensorPortfolioBuilder.build(state: state, catalogue: try? catalogue?.get())

        let isFullyPriced = portfolio.isFullyPriced || catalogue != nil ? portfolio.isFullyPriced : nil

        return Valuation(stake: portfolio.pricedTaoValue, isFullyPriced: isFullyPriced)
    }

    func refresh(
        latestState: @escaping () -> Multistaking.SubtensorStakingState?,
        runningCallbackIn callbackQueue: DispatchQueue,
        mutex: NSLock,
        onUpdate: @escaping (Bool) -> Void
    ) {
        guard !callStore.hasCall, (latestState()?.subnetCount ?? 0) > 0 else {
            return
        }

        executeCancellable(
            wrapper: catalogueService.createCatalogueWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: callbackQueue,
            mutex: mutex
        ) { [weak self] result in
            self?.apply(result, to: latestState(), onUpdate: onUpdate)
        }
    }
}

private extension SubtensorCataloguePricingTracker {
    func apply(
        _ result: Result<SubtensorSubnetCatalogue, Error>,
        to state: Multistaking.SubtensorStakingState?,
        onUpdate: (Bool) -> Void
    ) {
        if case let .failure(error) = result {
            logger.warning("Subnet catalogue fetch error: \(error)")
        }

        guard let state else {
            catalogue = result
            return
        }

        let previous = valuation(of: state)

        catalogue = result

        onUpdate(valuation(of: state) != previous)
    }
}
