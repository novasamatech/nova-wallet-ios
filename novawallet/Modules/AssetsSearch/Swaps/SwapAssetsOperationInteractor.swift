import BigInt
import RobinHood

final class SwapAssetsOperationInteractor: AnyCancellableCleaning {
    weak var presenter: SwapAssetsOperationPresenterProtocol?

    let stateObservable: AssetListModelObservable
    let logger: LoggerProtocol
    let chainAsset: ChainAsset?
    let assetConversionOperationFactory: AssetConversionOperationFactoryProtocol

    private let operationQueue: OperationQueue
    private var builder: AssetSearchBuilder?
    private var directionsCall: CancellableCall?
    private var availableDirections: [ChainAssetId: Set<ChainAssetId>]?

    init(
        stateObservable: AssetListModelObservable,
        chainAsset: ChainAsset?,
        assetConversionOperationFactory: AssetConversionOperationFactoryProtocol,
        logger: LoggerProtocol,
        operationQueue: OperationQueue
    ) {
        self.stateObservable = stateObservable
        self.logger = logger
        self.chainAsset = chainAsset
        self.assetConversionOperationFactory = assetConversionOperationFactory
        self.operationQueue = operationQueue
    }

    private func loadDirections() {
        if let chainAsset = chainAsset {
            loadDirections(for: chainAsset)
        } else {
            loadAllDirections()
        }
    }

    private func loadAllDirections() {
        let wrapper = assetConversionOperationFactory.availableDirections()
        loadDirections(wrapper: wrapper, mapper: { $0 })
    }

    private func loadDirections(for chainAsset: ChainAsset) {
        let wrapper = assetConversionOperationFactory.availableDirectionsForAsset(chainAsset.chainAssetId)
        loadDirections(wrapper: wrapper) {
            var result = [ChainAssetId: Set<ChainAssetId>]()
            result[chainAsset.chainAssetId] = $0
            return result
        }
    }

    private func loadDirections<Result>(
        wrapper: CompoundOperationWrapper<Result>,
        mapper: @escaping (Result) -> [ChainAssetId: Set<ChainAssetId>]
    ) {
        clear(cancellable: &directionsCall)

        wrapper.targetOperation.completionBlock = { [weak self] in
            guard self?.directionsCall === wrapper else {
                return
            }

            self?.directionsCall = nil

            DispatchQueue.main.async {
                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.availableDirections = mapper(result)
                    self?.createBuilder()
                    self?.presenter?.directionsLoaded()
                } catch {
                    self?.presenter?.didReceive(error: .directions(error))
                }
            }
        }

        directionsCall = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func createBuilder() {
        let searchQueue = OperationQueue()
        searchQueue.maxConcurrentOperationCount = 1

        let filter: ChainAssetsFilter = { [weak self] chainAsset in
            guard let availableDirections = self?.availableDirections else {
                return false
            }
            return availableDirections[chainAsset.chainAssetId]?.isEmpty == false
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
        }
    }
}

extension SwapAssetsOperationInteractor: SwapAssetsOperationInteractorInputProtocol {
    func setup() {
        loadDirections()
    }

    func search(query: String) {
        builder?.apply(query: query)
    }
}
