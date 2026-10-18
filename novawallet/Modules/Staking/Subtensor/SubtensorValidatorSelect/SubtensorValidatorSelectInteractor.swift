import Foundation
import Operation_iOS

final class SubtensorValidatorSelectInteractor: AnyCancellableCleaning, SubtensorLoadDelivering {
    weak var presenter: SubtensorValidatorSelectInteractorOutputProtocol?

    let target: SubtensorStakeTarget
    let directoryOperationFactory: SubtensorValidatorDirectoryOperationFactoryProtocol
    let yieldOperationFactory: SubtensorYieldOperationFactoryProtocol
    let catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol
    let recommendationOperationFactory: SubtensorRecommendationOperationFactoryProtocol
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
        directoryOperationFactory = state.earnServices.validatorDirectoryOperationFactory
        yieldOperationFactory = state.earnServices.yieldOperationFactory
        catalogueOperationFactory = state.earnServices.catalogueOperationFactory
        recommendationOperationFactory = state.earnServices.recommendationOperationFactory
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
            wrapper: directoryOperationFactory.createDirectoryWrapper(for: target.subnetRef),
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
            yieldOperationFactory.createAlphaYieldsWrapper(for: target.netuid),
            in: yieldStore,
            label: "validator yields"
        ) { [weak self] in
            self?.presenter?.didReceive(yields: $0)
        }
    }

    func loadVerification(listedHotkeys: [AccountId]) {
        verificationStore.cancel()

        executeCancellable(
            wrapper: recommendationOperationFactory.createListVerificationWrapper(
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
            catalogueOperationFactory.createCatalogueWrapper(),
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

extension SubtensorValidatorSelectInteractor: SubtensorValidatorSelectInteractorInputProtocol {
    func setup() {
        let subnet = target.subnetRef
        let isRoot = target.isRoot
        let directoryOperationFactory = directoryOperationFactory
        let yieldOperationFactory = yieldOperationFactory
        let catalogueOperationFactory = catalogueOperationFactory

        loadCached({
            SubtensorValidatorSelectSnapshot(
                directory: directoryOperationFactory.cachedDirectory(for: subnet),
                yields: yieldOperationFactory.cachedAlphaYields(for: subnet.netuid),
                alphaPrice: isRoot
                    ? .miss
                    : catalogueOperationFactory.cachedCatalogue().map { $0.subnet(for: subnet)?.freshTaoPerAlpha }
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
