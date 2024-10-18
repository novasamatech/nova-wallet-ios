import Foundation
import Operation_iOS

protocol AssetsExchangeGraphProviding {
    func setup()
    func throttle()
    func subscribeGraph(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping (AssetsExchangeGraphProtocol?) -> Void
    )
}

final class AssetsExchangeGraphProvider {
    let supportedExchangeProviders: [AssetsExchangeProviding]
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let syncQueue: DispatchQueue
    private var edgesRequestPerProvider: [Int: CancellableCallStore]
    private var graphPerProvider: [Int: AssetsExchangeGraphModel] = [:]
    private var observableState: Observable<NotEqualWrapper<AssetsExchangeGraphProtocol?>> = .init(
        state: .init(value: nil)
    )

    init(
        supportedExchangeProviders: [AssetsExchangeProviding],
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.supportedExchangeProviders = supportedExchangeProviders
        self.operationQueue = operationQueue
        self.logger = logger

        edgesRequestPerProvider = supportedExchangeProviders.enumerated().reduce(into: [:]) {
            $0[$1.offset] = CancellableCallStore()
        }

        syncQueue = DispatchQueue(label: "io.novawallet.exchangegraphprovider.\(UUID().uuidString)")
    }

    private func updateExchanges(_ exchanges: [AssetsExchangeProtocol], providerIndex: Int) {
        guard let cancellableStore = edgesRequestPerProvider[providerIndex] else {
            return
        }

        cancellableStore.cancel()

        let edgeWrappers = exchanges.map { $0.availableDirectSwapConnections() }

        let graphOperation = ClosureOperation<AssetsExchangeGraphModel> {
            let edges = try edgeWrappers
                .flatMap { try $0.targetOperation.extractNoCancellableResultData() }
                .map { AnyAssetExchangeEdge($0) }

            return GraphModelFactory.createFromEdges(edges)
        }

        edgeWrappers.forEach { graphOperation.addDependency($0.targetOperation) }
        let dependencies = edgeWrappers.flatMap(\.allOperations)

        let totalWrapper = CompoundOperationWrapper(targetOperation: graphOperation, dependencies: dependencies)

        executeCancellable(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: syncQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(graph):
                logger.debug("Did receive graph for provider \(providerIndex).")

                graphPerProvider[providerIndex] = graph
                rebuildGraph()
            case let .failure(error):
                logger.error("Did receive error: \(error).")
            }
        }
    }

    private func rebuildGraph() {
        let graphModel: AssetsExchangeGraphModel = graphPerProvider.values.reduce(
            AssetsExchangeGraphModel(connections: [:])
        ) { currentGraph, nextGraph in
            currentGraph.merging(with: nextGraph)
        }

        let graph = AssetsExchangeGraph(model: graphModel)
        observableState.state = .init(value: graph)
    }
}

extension AssetsExchangeGraphProvider: AssetsExchangeGraphProviding {
    func setup() {
        supportedExchangeProviders.enumerated().forEach { index, provider in
            provider.provide(notifingIn: syncQueue) { [weak self] exchanges in
                self?.updateExchanges(exchanges, providerIndex: index)
            }
        }
    }

    func throttle() {
        supportedExchangeProviders.forEach { $0.stop() }
    }

    func subscribeGraph(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping (AssetsExchangeGraphProtocol?) -> Void
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
}
