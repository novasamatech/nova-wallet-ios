import Foundation
import Operation_iOS

final class AssetsExchangeGraphProvider {
    let selectedWallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let feeSupportProvider: AssetsExchangeFeeSupportProviding
    let suffiencyProvider: AssetExchangeSufficiencyProviding
    let supportedExchangeProviders: [AssetsExchangeProviding]
    let delayedCallExecProvider: WalletDelayedExecutionProviding
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let syncQueue: DispatchQueue
    private var edgesRequestPerProvider: [Int: CancellableCallStore]
    private var graphPerProvider: [Int: AssetsExchangeGraphModel] = [:]
    private var observableState: Observable<NotEqualWrapper<AssetsExchangeGraphProtocol?>> = .init(
        state: .init(value: nil)
    )

    private var feeSupporting: AssetExchangeFeeSupporting?

    init(
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        supportedExchangeProviders: [AssetsExchangeProviding],
        feeSupportProvider: AssetsExchangeFeeSupportProviding,
        suffiencyProvider: AssetExchangeSufficiencyProviding,
        delayedCallExecProvider: WalletDelayedExecutionProviding,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.chainRegistry = chainRegistry
        self.supportedExchangeProviders = supportedExchangeProviders
        self.feeSupportProvider = feeSupportProvider
        self.suffiencyProvider = suffiencyProvider
        self.delayedCallExecProvider = delayedCallExecProvider
        self.operationQueue = operationQueue
        self.logger = logger

        edgesRequestPerProvider = supportedExchangeProviders.enumerated().reduce(into: [:]) {
            $0[$1.offset] = CancellableCallStore()
        }

        syncQueue = DispatchQueue(label: "io.novawallet.exchangegraphprovider.\(UUID().uuidString)")
    }

    private func clearCurrentRequests() {
        edgesRequestPerProvider.values.forEach { $0.cancel() }
    }

    private func updateExchanges(
        _ exchanges: [AssetsExchangeProtocol],
        providerIndex: Int
    ) {
        guard let cancellableStore = edgesRequestPerProvider[providerIndex] else {
            return
        }

        cancellableStore.cancel()

        let edgeWrappers = exchanges.map { $0.availableDirectSwapConnections() }

        let graphOperation = ClosureOperation<AssetsExchangeGraphModel> {
            let edges = edgeWrappers
                .flatMap { edgeWrapper in
                    do {
                        return try edgeWrapper.targetOperation.extractNoCancellableResultData()
                    } catch {
                        self.logger.warning("Edge wrapper failed (provider \(providerIndex)): \(error)")
                        return []
                    }
                }
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
                logger.error("Did receive error (provider index \(providerIndex)): \(error).")
            }
        }
    }

    private func rebuildGraph() {
        let graphModel: AssetsExchangeGraphModel = graphPerProvider.values.reduce(
            AssetsExchangeGraphModel(connections: [:])
        ) { currentGraph, nextGraph in
            currentGraph.merging(with: nextGraph)
        }

        let filter = AssetExchangePathFilter(
            selectedWallet: selectedWallet,
            chainRegistry: chainRegistry,
            sufficiencyProvider: suffiencyProvider,
            feeSupport: feeSupporting ?? CompoundAssetExchangeFeeSupport(supporters: []),
            delayedCallExecVerifier: delayedCallExecProvider.getCurrentState()
        )

        let graph = AssetsExchangeGraph(model: graphModel, filter: AnyGraphEdgeFilter(filter: filter))

        supportedExchangeProviders.forEach { $0.inject(graph: graph) }

        observableState.state = .init(value: graph)
    }
}

extension AssetsExchangeGraphProvider: AssetsExchangeGraphProviding {
    func setup() {
        supportedExchangeProviders.enumerated().forEach { index, provider in
            provider.setup()

            provider.subscribeExchanges(
                self,
                notifyingIn: syncQueue
            ) { [weak self] exchanges in
                self?.updateExchanges(exchanges, providerIndex: index)
            }
        }

        feeSupportProvider.setup()

        feeSupportProvider.subscribeFeeSupport(
            self,
            notifyingIn: syncQueue
        ) { [weak self] newState in
            self?.feeSupporting = newState
            self?.rebuildGraph()
        }

        delayedCallExecProvider.setup()

        delayedCallExecProvider.subscribeDelayedExecVerifier(
            self,
            notifyingIn: syncQueue
        ) { [weak self] _ in
            self?.rebuildGraph()
        }
    }

    func throttle() {
        supportedExchangeProviders.forEach { provider in
            provider.unsubscribeExchanges(self)
            provider.throttle()
        }

        feeSupportProvider.unsubscribe(self)

        delayedCallExecProvider.unsubscribe(self)

        syncQueue.async {
            self.clearCurrentRequests()
        }
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

    func unsubscribeGraph(_ target: AnyObject) {
        syncQueue.async { [weak self] in
            self?.observableState.removeObserver(by: target)
        }
    }
}
