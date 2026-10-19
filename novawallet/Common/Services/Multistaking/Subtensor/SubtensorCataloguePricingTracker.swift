import Foundation
import Operation_iOS

final class SubtensorCataloguePricingTracker {
    struct Valuation: Equatable {
        let stake: Balance
        let isFullyPriced: Bool?
    }

    let alphaPriceOperationFactory: SubtensorAlphaPriceOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var prices: Result<SubtensorAlphaPrices, Error>?
    private var requestedNetuids: Set<UInt16> = []
    private let callStore = CancellableCallStore()

    var alphaPrices: SubtensorAlphaPrices? {
        guard case let .success(alphaPrices) = prices else {
            return nil
        }

        return alphaPrices
    }

    init(
        alphaPriceOperationFactory: SubtensorAlphaPriceOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.alphaPriceOperationFactory = alphaPriceOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func seed() {
        guard prices == nil else {
            return
        }

        prices = alphaPriceOperationFactory.cachedPrices().map { .success($0) }
    }

    func cancel() {
        callStore.cancel()
    }

    func reset() {
        callStore.cancel()
        prices = nil
    }

    func valuation(of state: Multistaking.SubtensorState) -> Valuation {
        let portfolio = SubtensorPortfolioBuilder.build(state: state, prices: try? prices?.get())

        let isFullyPriced = portfolio.isFullyPriced || prices != nil ? portfolio.isFullyPriced : nil

        return Valuation(stake: portfolio.pricedTaoValue, isFullyPriced: isFullyPriced)
    }

    func refresh(
        latestState: @escaping () -> Multistaking.SubtensorState?,
        runningCallbackIn callbackQueue: DispatchQueue,
        mutex: NSLock,
        onUpdate: @escaping (Bool) -> Void
    ) {
        guard let netuids = latestState()?.heldSubnetNetuids, !netuids.isEmpty else {
            return
        }

        guard !callStore.hasCall || netuids != requestedNetuids else {
            return
        }

        requestedNetuids = netuids
        callStore.cancel()

        executeCancellable(
            wrapper: alphaPriceOperationFactory.createPricesWrapper(for: netuids),
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
        _ result: Result<SubtensorAlphaPrices, Error>,
        to state: Multistaking.SubtensorState?,
        onUpdate: (Bool) -> Void
    ) {
        if case let .failure(error) = result {
            logger.warning("Alpha prices fetch error: \(error)")
        }

        guard let state else {
            prices = result
            return
        }

        let previous = valuation(of: state)

        prices = result

        onUpdate(valuation(of: state) != previous)
    }
}
