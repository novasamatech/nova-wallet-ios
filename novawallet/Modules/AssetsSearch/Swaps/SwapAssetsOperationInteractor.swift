import BigInt
import RobinHood

final class SwapAssetsOperationInteractor: AnyCancellableCleaning {
    weak var presenter: SwapAssetsOperationPresenterProtocol?

    let stateObservable: AssetListModelObservable
    let logger: LoggerProtocol
    let chainAsset: ChainAsset?
    let assetConversionAggregation: AssetConversionAggregationFactoryProtocol

    private let operationQueue: OperationQueue
    private var builder: AssetSearchBuilder?
    private var directionsCall = CancellableCallStore()
    private var availableDirections: [ChainAssetId: Set<ChainAssetId>] = [:]
    private var availableChains: Set<ChainModel.Id> = []

    init(
        stateObservable: AssetListModelObservable,
        chainAsset: ChainAsset?,
        assetConversionAggregation: AssetConversionAggregationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.stateObservable = stateObservable
        self.logger = logger
        self.chainAsset = chainAsset
        self.assetConversionAggregation = assetConversionAggregation
        self.operationQueue = operationQueue
    }

    deinit {
        directionsCall.cancel()
    }

    private func reloadDirectionsIfNeeded() {
        if let chainAsset = chainAsset {
            guard !availableChains.contains(chainAsset.chain.chainId), chainAsset.chain.hasSwaps else {
                presenter?.directionsLoaded()
                return
            }

            availableChains.insert(chainAsset.chain.chainId)
            availableDirections = [:]
            loadAssetDirections(for: chainAsset)
        } else {
            let allChains = stateObservable.state.value.allChains.values

            let chainsWithSwaps = allChains.filter(\.hasSwaps)
            let chainsWithSwapsIds = Set(chainsWithSwaps.map(\.chainId))

            if chainsWithSwapsIds != availableChains {
                availableChains = chainsWithSwapsIds
                availableDirections = [:]

                loadDirections(for: chainsWithSwaps)
            } else {
                presenter?.directionsLoaded()
            }
        }
    }

    private func loadDirections(for chains: [ChainModel]) {
        directionsCall.cancel()

        let wrappers = chains.map { assetConversionAggregation.createAvailableDirectionsWrapper(for: $0) }

        let dependencies = wrappers.flatMap(\.allOperations)

        let mergingOperation = ClosureOperation<Void> {
            try wrappers.forEach { _ = try $0.targetOperation.extractNoCancellableResultData() }
        }

        dependencies.forEach {
            mergingOperation.addDependency($0)
        }

        let commonWrapper = CompoundOperationWrapper(targetOperation: mergingOperation, dependencies: dependencies)

        wrappers.forEach { wrapper in
            wrapper.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }

                    if case let .success(directions) = wrapper.targetOperation.result {
                        self.updateAvailableDirections(directions)
                    }
                }
            }
        }

        executeCancellable(
            wrapper: commonWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: directionsCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.directionsLoaded()
            case let .failure(error):
                self?.presenter?.didReceive(error: .directions(error))
            }
        }
    }

    private func loadAssetDirections(for chainAsset: ChainAsset) {
        directionsCall.cancel()

        let wrapper = assetConversionAggregation.createAvailableDirectionsWrapper(for: chainAsset)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: directionsCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(directions):
                self?.updateAvailableDirections([chainAsset.chainAssetId: directions])
                self?.presenter?.directionsLoaded()
            case let .failure(error):
                self?.presenter?.didReceive(error: .directions(error))
            }
        }
    }

    private func updateAvailableDirections(_ newDirections: [ChainAssetId: Set<ChainAssetId>]) {
        availableDirections = newDirections.reduce(into: availableDirections) { accum, keyValue in
            accum[keyValue.key] = keyValue.value
        }

        builder?.reload()
    }

    private func createBuilder() {
        let searchQueue = OperationQueue()
        searchQueue.maxConcurrentOperationCount = 1

        let filter: ChainAssetsFilter = { [weak self] chainAsset in
            guard let availableDirections = self?.availableDirections else {
                return false
            }
            return availableDirections.contains(where: { $0.value.contains(chainAsset.chainAssetId) })
        }

        builder = .init(
            filter: filter,
            workingQueue: .main,
            callbackQueue: .main,
            callbackClosure: { [weak self] result in
                self?.presenter?.didReceive(result: result)
            },
            operationQueue: searchQueue,
            logger: logger
        )

        builder?.apply(model: stateObservable.state.value)

        stateObservable.addObserver(with: self) { [weak self] _, newState in
            guard let self = self else {
                return
            }
            self.builder?.apply(model: newState.value)
            self.reloadDirectionsIfNeeded()
        }
    }
}

extension SwapAssetsOperationInteractor: SwapAssetsOperationInteractorInputProtocol {
    func setup() {
        createBuilder()
        reloadDirectionsIfNeeded()
    }

    func search(query: String) {
        builder?.apply(query: query)
    }
}
