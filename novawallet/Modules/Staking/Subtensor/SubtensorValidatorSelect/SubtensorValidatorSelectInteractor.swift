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
                let clientGates = recommendationService.lastSeenClientGates() ?? .backendDefault
                presenter?.didReceive(directory: directory, clientGates: clientGates)
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
                self?.presenter?.didReceive(alphaPrice: catalogue.subnet(for: subnet)?.taoPerAlpha)
            case let .failure(error):
                self?.logger.warning("Subnet catalogue unavailable for validator stakes: \(error)")
                self?.presenter?.didReceive(alphaPrice: nil)
            }
        }
    }

    func loadAll() {
        loadDirectory()

        guard !target.isRoot else {
            return
        }

        loadYields()
        loadAlphaPrice()
    }
}

extension SubtensorValidatorSelectInteractor: ValidatorSelectInteractorInputProtocol {
    func setup() {
        loadAll()
    }

    func retry() {
        loadAll()
    }
}
