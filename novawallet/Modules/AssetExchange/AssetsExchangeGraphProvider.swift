import Foundation
import Operation_iOS

final class AssetsExchangeGraphProvider {
    let selectedWallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let feeSupportProvider: AssetExchangeFeeSupportProviding
    let suffiencyProvider: AssetExchangeSufficiencyProviding
    let supportedExchangeProviders: [AssetsExchangeProviding]
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let syncQueue: DispatchQueue
    private var edgesRequestPerProvider: [Int: CancellableCallStore]
    private var graphPerProvider: [Int: AssetsExchangeGraphModel] = [:]
    private var observableState: Observable<NotEqualWrapper<AssetsExchangeGraphProtocol?>> = .init(
        state: .init(value: nil)
    )

    private var feeSupporters: [String: AssetExchangeFeeSupporting] = [:]
    private var feeFetchRequests: [String: CancellableCallStore] = [:]

    init(
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        supportedExchangeProviders: [AssetsExchangeProviding],
        feeSupportProvider: AssetExchangeFeeSupportProviding,
        suffiencyProvider: AssetExchangeSufficiencyProviding,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.chainRegistry = chainRegistry
        self.supportedExchangeProviders = supportedExchangeProviders
        self.feeSupportProvider = feeSupportProvider
        self.suffiencyProvider = suffiencyProvider
        self.operationQueue = operationQueue
        self.logger = logger

        edgesRequestPerProvider = supportedExchangeProviders.enumerated().reduce(into: [:]) {
            $0[$1.offset] = CancellableCallStore()
        }

        syncQueue = DispatchQueue(label: "io.novawallet.exchangegraphprovider.\(UUID().uuidString)")
    }

    private func clearCurrentRequests() {
        edgesRequestPerProvider.values.forEach { $0.cancel() }
        feeFetchRequests.values.forEach { $0.cancel() }
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

    private func updateFeeSupport(for fetchers: [AssetExchangeFeeSupportFetching]) {
        feeFetchRequests.values.forEach { $0.cancel() }
        feeFetchRequests = [:]

        let oldFeeSupportIds = Set(feeSupporters.keys)
        let newFeeSupportIds = Set(fetchers.map(\.identifier))

        let idsToRemove = oldFeeSupportIds.subtracting(newFeeSupportIds)

        if !idsToRemove.isEmpty {
            idsToRemove.forEach { feeSupporters[$0] = nil }
            rebuildGraph()
        }

        fetchers.forEach { fetcher in
            let callStore = CancellableCallStore()
            feeFetchRequests[fetcher.identifier] = callStore

            let wrapper = fetcher.createFeeSupportWrapper()

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: callStore,
                runningCallbackIn: syncQueue
            ) { [weak self] result in
                guard let self else {
                    return
                }

                switch result {
                case let .success(feeSupport):
                    logger.debug("Did receive fee support for \(fetcher.identifier).")

                    feeSupporters[fetcher.identifier] = feeSupport

                    rebuildGraph()
                case let .failure(error):
                    logger.error("Did receive error \(fetcher.identifier): \(error).")
                }
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
            feeSupport: CompoundAssetExchangeFeeSupport(supporters: Array(feeSupporters.values))
        )

        let graph = AssetsExchangeGraph(model: graphModel, filter: AnyGraphEdgeFilter(filter: filter))

        observableState.state = .init(value: graph)

        supportedExchangeProviders.forEach { $0.inject(graph: graph) }
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

        feeSupportProvider.subscribeFeeFetchers(
            self,
            notifyingIn: syncQueue
        ) { [weak self] fetchers in
            self?.updateFeeSupport(for: fetchers)
        }
    }

    func throttle() {
        supportedExchangeProviders.forEach { provider in
            provider.unsubscribeExchanges(self)
            provider.throttle()
        }

        feeSupportProvider.unsubscribeFeeFetchers(self)

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
