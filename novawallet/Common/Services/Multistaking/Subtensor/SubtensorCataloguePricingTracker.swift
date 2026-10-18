import Foundation
import Operation_iOS

final class SubtensorCataloguePricingTracker {
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

    func seed() {
        guard case let .fresh(seed, _) = catalogueService.cachedCatalogue() else {
            catalogue = nil
            return
        }

        catalogue = .success(seed)
    }

    func cancel() {
        callStore.cancel()
    }

    func isFullyPriced(_ state: Multistaking.SubtensorStakingState) -> Bool? {
        let portfolio = SubtensorPortfolioBuilder.build(state: state, catalogue: try? catalogue?.get())

        guard portfolio.isFullyPriced || catalogue != nil else {
            return nil
        }

        return portfolio.isFullyPriced
    }

    func refresh(
        latestState: @escaping () -> Multistaking.SubtensorStakingState?,
        runningCallbackIn callbackQueue: DispatchQueue,
        mutex: NSLock,
        onChange: @escaping () -> Void
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
            self?.apply(result, to: latestState(), onChange: onChange)
        }
    }
}

private extension SubtensorCataloguePricingTracker {
    func apply(
        _ result: Result<SubtensorSubnetCatalogue, Error>,
        to state: Multistaking.SubtensorStakingState?,
        onChange: () -> Void
    ) {
        if case let .failure(error) = result {
            logger.warning("Subnet catalogue fetch error: \(error)")
        }

        guard let state else {
            catalogue = result
            return
        }

        let wasFullyPriced = isFullyPriced(state)

        catalogue = result

        if isFullyPriced(state) != wasFullyPriced {
            onChange()
        }
    }
}
