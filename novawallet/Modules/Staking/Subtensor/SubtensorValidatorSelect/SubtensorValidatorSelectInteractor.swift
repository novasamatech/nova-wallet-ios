import Foundation
import Operation_iOS

final class SubtensorValidatorSelectInteractor: AnyCancellableCleaning {
    weak var presenter: ValidatorSelectInteractorOutputProtocol?

    let target: SubtensorStakeTarget
    let directoryService: SubtensorValidatorDirectoryServiceProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let recommendationService: SubtensorRecommendationServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let directoryStore = CancellableCallStore()
    private let yieldStore = CancellableCallStore()
    private let catalogueStore = CancellableCallStore()
    private let recommendedStore = CancellableCallStore()

    init(
        target: SubtensorStakeTarget,
        directoryService: SubtensorValidatorDirectoryServiceProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        recommendationService: SubtensorRecommendationServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.target = target
        self.directoryService = directoryService
        self.yieldService = yieldService
        self.catalogueService = catalogueService
        self.recommendationService = recommendationService
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        directoryStore.cancel()
        yieldStore.cancel()
        catalogueStore.cancel()
        recommendedStore.cancel()
    }
}

private extension SubtensorValidatorSelectInteractor {
    var subnet: SubtensorSubnetRef {
        SubtensorSubnetRef(netuid: target.netuid, registeredAt: target.subnetInfo?.networkRegisteredAt ?? 0)
    }

    func loadDirectory() {
        directoryStore.cancel()

        executeCancellable(
            wrapper: directoryService.createDirectoryWrapper(for: subnet),
            inOperationQueue: operationQueue,
            backingCallIn: directoryStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(directory):
                presenter?.didReceive(directory: directory)
            case let .failure(error):
                logger.warning("Subnet validators unavailable: \(error)")
                presenter?.didFailDirectory(error)
            }
        }
    }

    func loadYields() {
        yieldStore.cancel()

        executeCancellable(
            wrapper: yieldService.createAlphaYieldsWrapper(for: subnet.netuid),
            inOperationQueue: operationQueue,
            backingCallIn: yieldStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yields):
                self?.presenter?.didReceive(yields: yields)
            case let .failure(error):
                self?.logger.warning("Subnet validator yields unavailable: \(error)")
                self?.presenter?.didReceive(yields: nil)
            }
        }
    }

    func loadRecommended() {
        recommendedStore.cancel()

        executeCancellable(
            wrapper: recommendationService.createRecommendedValidatorsWrapper(for: subnet),
            inOperationQueue: operationQueue,
            backingCallIn: recommendedStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(recommended):
                self?.presenter?.didReceive(recommendedHotkeys: Set(recommended.validators.map(\.hotkey)))
            case let .failure(error):
                self?.logger.warning("Recommended validators unavailable for the list filter: \(error)")
                self?.presenter?.didFailRecommended(error)
            }
        }
    }

    func loadAlphaPrice() {
        catalogueStore.cancel()

        let subnet = subnet

        executeCancellable(
            wrapper: catalogueService.createCatalogueWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: catalogueStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(catalogue):
                self?.presenter?.didReceive(alphaPrice: catalogue.subnet(for: subnet)?.freshTaoPerAlpha)
            case let .failure(error):
                self?.logger.warning("Subnet catalogue unavailable for validator stakes: \(error)")
                self?.presenter?.didReceive(alphaPrice: nil)
            }
        }
    }

    func loadAll() {
        loadDirectory()
        loadYields()
        loadRecommended()

        guard !target.isRoot else {
            return
        }

        loadAlphaPrice()
    }
}

extension SubtensorValidatorSelectInteractor: ValidatorSelectInteractorInputProtocol {
    func cachedSnapshot() -> SubtensorValidatorSelectSnapshot {
        let subnet = subnet

        return SubtensorValidatorSelectSnapshot(
            yields: yieldService.cachedAlphaYields(for: subnet.netuid),
            alphaPrice: target.isRoot
                ? .miss
                : catalogueService.cachedCatalogue().map { $0.subnet(for: subnet)?.freshTaoPerAlpha }
        )
    }

    func setup() {
        loadAll()
    }

    func retry() {
        loadAll()
    }
}
