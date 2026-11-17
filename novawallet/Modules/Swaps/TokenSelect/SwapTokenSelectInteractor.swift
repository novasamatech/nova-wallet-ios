import Foundation
import Operation_iOS

final class SwapTokenSelectInteractor {
    weak var presenter: SwapTokenSelectInteractorOutputProtocol?

    let state: SwapTokensFlowStateProtocol
    let side: SwapTokenSelectionSide
    let counterpart: ChainAsset?
    let networksStore: SwapTokenSelectNetworksStoring
    let operationQueue: OperationQueue

    private var assetExchangeService: AssetsExchangeServiceProtocol?
    private let universeCallStore = CancellableCallStore()
    private let swappableCallStore = CancellableCallStore()
    private var hasReportedRoutesFailure = false

    init(
        state: SwapTokensFlowStateProtocol,
        side: SwapTokenSelectionSide,
        counterpart: ChainAsset?,
        networksStore: SwapTokenSelectNetworksStoring,
        operationQueue: OperationQueue
    ) {
        self.state = state
        self.side = side
        self.counterpart = counterpart
        self.networksStore = networksStore
        self.operationQueue = operationQueue
    }

    deinit {
        universeCallStore.cancel()
        swappableCallStore.cancel()
    }
}

// MARK: Private

private extension SwapTokenSelectInteractor {
    func subscribeAssetList() {
        presenter?.didReceive(assetList: state.assetListObservable.state.value)

        state.assetListObservable.addObserver(with: self) { [weak self] _, newState in
            self?.presenter?.didReceive(assetList: newState.value)
        }
    }

    func subscribeRoutes() {
        let service = state.setupAssetExchangeService()
        assetExchangeService = service

        service.subscribeUpdates(for: self, notifyingIn: .main) { [weak self] in
            self?.refreshRoutes()
        }
    }

    func fetchRouteUniverse(using service: AssetsExchangeServiceProtocol) {
        let wrapper = switch side {
        case .pay:
            service.fetchAssetsInWrapper(given: nil)
        case .receive:
            service.fetchAssetsOutWrapper(given: nil)
        }

        fetch(wrapper: wrapper, callStore: universeCallStore) { [weak self] chainAssetIds in
            self?.presenter?.didReceive(routeUniverse: chainAssetIds)
        }
    }

    func fetchSwappable(with counterpartId: ChainAssetId, using service: AssetsExchangeServiceProtocol) {
        let wrapper = switch side {
        case .pay:
            service.fetchAssetsInWrapper(given: counterpartId)
        case .receive:
            service.fetchAssetsOutWrapper(given: counterpartId)
        }

        fetch(wrapper: wrapper, callStore: swappableCallStore) { [weak self] chainAssetIds in
            self?.presenter?.didReceive(swappable: chainAssetIds)
        }
    }

    func fetch(
        wrapper: CompoundOperationWrapper<Set<ChainAssetId>>,
        callStore: CancellableCallStore,
        completion: @escaping (Set<ChainAssetId>) -> Void
    ) {
        callStore.cancel()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chainAssetIds):
                completion(chainAssetIds)
            case let .failure(error):
                self?.reportRoutesFailure(error)
            }
        }
    }

    func reportRoutesFailure(_ error: Error) {
        guard !hasReportedRoutesFailure else {
            return
        }

        hasReportedRoutesFailure = true
        presenter?.didReceive(error: .routes(error))
    }
}

// MARK: SwapTokenSelectInteractorInputProtocol

extension SwapTokenSelectInteractor: SwapTokenSelectInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(savedNetworks: networksStore.savedNetworks)

        subscribeAssetList()
        subscribeRoutes()
    }

    func refreshRoutes() {
        guard let assetExchangeService else {
            return
        }

        hasReportedRoutesFailure = false

        fetchRouteUniverse(using: assetExchangeService)

        if let counterpartId = counterpart?.chainAssetId {
            fetchSwappable(with: counterpartId, using: assetExchangeService)
        }
    }

    func save(networks: [ChainModel.Id], replacing shownNetworks: Set<ChainModel.Id>) {
        let savedNetworks = SwapTokenSelectNetworksArranger.savedNetworks(
            ticked: networks,
            shown: shownNetworks,
            previouslySaved: networksStore.savedNetworks
        )

        networksStore.save(networks: savedNetworks)
        presenter?.didReceive(savedNetworks: savedNetworks)
    }
}
