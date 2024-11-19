import Foundation

class AssetsExchangeBaseProvider {
    let chainRegistry: ChainRegistryProtocol
    let graphProxy: AssetExchangeGraphProxy

    private var observableState: Observable<NotEqualWrapper<[AssetsExchangeProtocol]>> = .init(
        state: .init(value: [])
    )

    let operationQueue: OperationQueue
    let syncQueue: DispatchQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        priceStore _: AssetExchangePriceStoring,
        operationQueue: OperationQueue,
        syncQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.syncQueue = syncQueue
        self.logger = logger

        graphProxy = AssetExchangeGraphProxy(
            operationQueue: operationQueue,
            logger: logger
        )
    }

    func updateState(with newExchanges: [AssetsExchangeProtocol]) {
        observableState.state = .init(value: newExchanges)
    }

    func performSetup() {
        fatalError("Must be overriden by subsclass")
    }

    func performThrottle() {
        fatalError("Must be overriden by subsclass")
    }
}

extension AssetsExchangeBaseProvider: AssetsExchangeProviding {
    func setup() {
        performSetup()
    }

    func throttle() {
        performThrottle()
    }

    func subscribeExchanges(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping ([AssetsExchangeProtocol]) -> Void
    ) {
        syncQueue.async { [weak self] in
            self?.observableState.addObserver(
                with: target,
                sendStateOnSubscription: true,
                queue: queue
            ) { _, newState in
                onChange(newState.value)
            }
        }
    }

    func unsubscribeExchanges(_ target: AnyObject) {
        syncQueue.async { [weak self] in
            self?.observableState.removeObserver(by: target)
        }
    }

    func inject(graph: AssetsExchangeGraphProtocol) {
        graphProxy.install(graph: graph)
    }
}
