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

    private var seed = SubtensorValidatorSelectSnapshot(
        directory: .miss,
        clientGates: .miss,
        yields: .miss,
        alphaPrice: .miss
    )
    private let directoryStore = CancellableCallStore()
    private let clientGatesStore = CancellableCallStore()
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
        clientGatesStore.cancel()
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
                presenter?.didReceive(directory: directory)
            case let .failure(error):
                logger.warning("Subnet validators unavailable: \(error)")
                presenter?.didFailDirectory(error)
            }
        }
    }

    func loadClientGates() {
        clientGatesStore.cancel()

        executeCancellable(
            wrapper: recommendationService.createClientGatesWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: clientGatesStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(clientGates):
                self?.presenter?.didReceive(clientGates: clientGates)
            case let .failure(error):
                self?.logger.warning("Subtensor client gates unavailable for the validator list: \(error)")
                self?.presenter?.didFailClientGates(error)
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
                self?.presenter?.didReceive(alphaPrice: catalogue.subnet(for: subnet)?.freshTaoPerAlpha)
            case let .failure(error):
                self?.logger.warning("Subnet catalogue unavailable for validator stakes: \(error)")
                self?.presenter?.didReceive(alphaPrice: nil)
            }
        }
    }

    func loadAll() {
        loadDirectory()
        loadClientGates()

        guard !target.isRoot else {
            return
        }

        loadYields()
        loadAlphaPrice()
    }

    func makeSnapshot() -> SubtensorValidatorSelectSnapshot {
        let subnet = subnet
        let directory = directoryService.cachedDirectory(for: subnet)
        let clientGates = recommendationService.cachedClientGates()

        guard !target.isRoot else {
            return SubtensorValidatorSelectSnapshot(
                directory: directory,
                clientGates: clientGates,
                yields: .miss,
                alphaPrice: .miss
            )
        }

        return SubtensorValidatorSelectSnapshot(
            directory: directory,
            clientGates: clientGates,
            yields: yieldService.cachedAlphaYields(for: subnet.netuid),
            alphaPrice: catalogueService.cachedCatalogue().map { $0.subnet(for: subnet)?.freshTaoPerAlpha }
        )
    }
}

extension SubtensorValidatorSelectInteractor: ValidatorSelectInteractorInputProtocol {
    func cachedSnapshot() -> SubtensorValidatorSelectSnapshot {
        seed = makeSnapshot()

        return seed
    }

    func setup() {
        if !seed.directory.isFresh {
            loadDirectory()
        }

        if !seed.clientGates.isFresh {
            loadClientGates()
        }

        guard !target.isRoot else {
            return
        }

        if !seed.yields.isFresh {
            loadYields()
        }

        if !seed.alphaPrice.isFresh {
            loadAlphaPrice()
        }
    }

    func retry() {
        loadAll()
    }
}
