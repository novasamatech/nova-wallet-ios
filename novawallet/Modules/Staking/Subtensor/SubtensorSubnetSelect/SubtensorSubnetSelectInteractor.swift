import Foundation
import Operation_iOS

final class SubtensorSubnetSelectInteractor: SubtensorLoadDelivering {
    weak var presenter: SubnetSelectInteractorOutputProtocol?

    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let maxApyProvider: SubtensorMaxApyProviderProtocol
    let earnSettings: SubtensorEarnSettingsProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let entriesStore = CancellableCallStore()
    private let logosStore = CancellableCallStore()
    private let weeklyStore = CancellableCallStore()
    private let apyStore = CancellableCallStore()

    init(state: SubtensorStakingSharedStateProtocol, operationQueue: OperationQueue, logger: LoggerProtocol) {
        catalogueService = state.earnServices.catalogueService
        subnetsService = state.subnetsService
        subnetLogosProvider = state.earnServices.subnetLogosProvider
        priceHistoryService = state.earnServices.priceHistoryService
        maxApyProvider = state.earnServices.maxApyProvider
        earnSettings = state.earnServices.earnSettings
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        [entriesStore, logosStore, weeklyStore, apyStore].forEach { $0.cancel() }
    }
}

private extension SubtensorSubnetSelectInteractor {
    func createEntriesWrapper() -> CompoundOperationWrapper<[SubtensorSubnetListItem]> {
        let catalogueWrapper = catalogueService.createCatalogueWrapper()
        let subnetsInfoWrapper = subnetsService.createSubnetsInfoWrapper()

        let entriesOperation = ClosureOperation<[SubtensorSubnetListItem]> {
            let catalogue = try catalogueWrapper.targetOperation.extractNoCancellableResultData()
            let subnetsInfo = try subnetsInfoWrapper.targetOperation.extractNoCancellableResultData()

            return SubtensorSubnetListBuilder.entries(from: catalogue, subnetsInfo: subnetsInfo)
        }

        entriesOperation.addDependency(catalogueWrapper.targetOperation)
        entriesOperation.addDependency(subnetsInfoWrapper.targetOperation)

        return catalogueWrapper
            .insertingHead(operations: subnetsInfoWrapper.allOperations)
            .insertingTail(operation: entriesOperation)
    }

    func provideEntries() {
        entriesStore.cancel()

        executeCancellable(
            wrapper: createEntriesWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: entriesStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(entries):
                self?.presenter?.didReceive(entries: entries)
            case let .failure(error):
                self?.logger.error("Subnet list unavailable: \(error)")
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    func provideSubnetLogos() {
        load(subnetLogosProvider.createLogosWrapper(), in: logosStore, label: "subnet marks") { [weak self] in
            self?.presenter?.didReceive(subnetLogos: $0)
        }
    }

    func provideFavourites() {
        presenter?.didReceive(favourites: earnSettings.favouriteSubnets)
    }

    func unavailablePrices<Value: Equatable>(
        for subnets: [SubtensorSubnetRef]
    ) -> [SubtensorSubnetRef: SubtensorPriceData<Value>] {
        Dictionary(subnets.map { ($0, .unavailable) }, uniquingKeysWith: { first, _ in first })
    }
}

extension SubtensorSubnetSelectInteractor: SubnetSelectInteractorInputProtocol {
    func setup() {
        provideFavourites()
        provideEntries()
        provideSubnetLogos()
    }

    func refresh() {
        provideEntries()
    }

    func refreshFavourites() {
        provideFavourites()
    }

    func toggleFavorite(_ subnetRef: SubtensorSubnetRef) {
        earnSettings.favouriteSubnets.formSymmetricDifference([subnetRef])
        provideFavourites()
    }

    func loadWeeklyPrices(for subnets: [SubtensorSubnetRef]) {
        weeklyStore.cancel()

        guard let priceHistoryService else {
            presenter?.didReceive(weeklyPrices: unavailablePrices(for: subnets))
            return
        }

        executeCancellable(
            wrapper: priceHistoryService.createWeeklyChangesWrapper(for: subnets),
            inOperationQueue: operationQueue,
            backingCallIn: weeklyStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(prices):
                presenter?.didReceive(weeklyPrices: prices)
            case let .failure(error):
                logger.warning("Subnet weekly prices unavailable: \(error)")
                presenter?.didReceive(weeklyPrices: unavailablePrices(for: subnets))
            }
        }
    }

    func loadApy() {
        apyStore.cancel()

        load(maxApyProvider.createMaxApyWrapper(), in: apyStore, label: "subnet apy") { [weak self] in
            self?.presenter?.didReceive(apy: $0)
        }
    }
}
