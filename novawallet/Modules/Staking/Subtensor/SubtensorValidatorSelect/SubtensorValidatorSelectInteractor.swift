import Foundation
import Operation_iOS

final class SubtensorValidatorSelectInteractor: AnyCancellableCleaning, SubtensorLoadDelivering {
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
    private let verificationStore = CancellableCallStore()

    init(
        target: SubtensorStakeTarget,
        state: SubtensorStakingSharedStateProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.target = target
        directoryService = state.earnServices.validatorDirectoryService
        yieldService = state.earnServices.yieldService
        catalogueService = state.earnServices.catalogueService
        recommendationService = state.earnServices.recommendationService
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        directoryStore.cancel()
        yieldStore.cancel()
        catalogueStore.cancel()
        verificationStore.cancel()
    }
}

private extension SubtensorValidatorSelectInteractor {
    func loadDirectory() {
        directoryStore.cancel()

        executeCancellable(
            wrapper: directoryService.createDirectoryWrapper(for: target.subnetRef),
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
                loadVerification(listedHotkeys: directory.items.map(\.hotkey))

                if target.isRoot {
                    loadYields()
                }
            case let .failure(error):
                logger.warning("Subnet validators unavailable: \(error)")
                presenter?.didFailDirectory(error)
            }
        }
    }

    func loadYields() {
        yieldStore.cancel()

        load(
            yieldService.createAlphaYieldsWrapper(for: target.netuid),
            in: yieldStore,
            label: "validator yields"
        ) { [weak self] in
            self?.presenter?.didReceive(yields: $0)
        }
    }

    func loadVerification(listedHotkeys: [AccountId]) {
        verificationStore.cancel()

        executeCancellable(
            wrapper: recommendationService.createListVerificationWrapper(
                for: target.subnetRef,
                listedHotkeys: listedHotkeys
            ),
            inOperationQueue: operationQueue,
            backingCallIn: verificationStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(verification):
                self?.presenter?.didReceive(verification: verification)
            case let .failure(error):
                self?.logger.warning("Validator list verification unavailable: \(error)")
                self?.presenter?.didFailVerification(error)
            }
        }
    }

    func loadAlphaPrice() {
        catalogueStore.cancel()

        let subnet = target.subnetRef

        load(
            catalogueService.createCatalogueWrapper(),
            in: catalogueStore,
            label: "catalogue for validator stakes"
        ) { [weak self] in
            self?.presenter?.didReceive(alphaPrice: $0?.subnet(for: subnet)?.freshTaoPerAlpha)
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
        let subnet = target.subnetRef
        let isRoot = target.isRoot
        let directoryService = directoryService
        let yieldService = yieldService
        let catalogueService = catalogueService

        loadCached({
            SubtensorValidatorSelectSnapshot(
                directory: directoryService.cachedDirectory(for: subnet),
                yields: yieldService.cachedAlphaYields(for: subnet.netuid),
                alphaPrice: isRoot
                    ? .miss
                    : catalogueService.cachedCatalogue().map { $0.subnet(for: subnet)?.freshTaoPerAlpha }
            )
        }, in: directoryStore, then: { [weak self] snapshot in
            self?.presenter?.didReceive(snapshot: snapshot)
            self?.loadAll()
        })
    }

    func retry() {
        loadAll()
    }
}
