import Foundation
import Foundation_iOS
import Operation_iOS

final class SubtensorOperationResultInteractor {
    weak var presenter: SubtensorResultInteractorOutputProtocol?

    let operation: SubtensorStakingOperation
    let coldkey: AccountId
    let loadsSubnetData: Bool
    let operationService: SubtensorStakingOperationServiceProtocol
    let chainFactory: SubtensorResultChainFactoryProtocol
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    let osMediator: OperatingSystemMediating
    let applicationHandler: ApplicationHandlerProtocol
    let schedulerFactory: (SchedulerDelegate) -> SchedulerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var seed: HTTPCachePeek<SubtensorSubnetCatalogue> = .miss
    private var confirmationScheduler: SchedulerProtocol?
    private var isSubmissionFinished = false

    init(
        operation: SubtensorStakingOperation,
        coldkey: AccountId,
        loadsSubnetData: Bool,
        operationService: SubtensorStakingOperationServiceProtocol,
        chainFactory: SubtensorResultChainFactoryProtocol,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol?,
        osMediator: OperatingSystemMediating,
        applicationHandler: ApplicationHandlerProtocol,
        schedulerFactory: @escaping (SchedulerDelegate) -> SchedulerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operation = operation
        self.coldkey = coldkey
        self.loadsSubnetData = loadsSubnetData
        self.operationService = operationService
        self.chainFactory = chainFactory
        self.catalogueService = catalogueService
        self.subnetLogosProvider = subnetLogosProvider
        self.positionsSyncService = positionsSyncService
        self.osMediator = osMediator
        self.applicationHandler = applicationHandler
        self.schedulerFactory = schedulerFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        confirmationScheduler?.cancel()
        osMediator.enableScreenSleep()
    }
}

private extension SubtensorOperationResultInteractor {
    func startConfirmationCap() {
        guard confirmationScheduler == nil, !isSubmissionFinished else {
            return
        }

        let scheduler = schedulerFactory(self)
        confirmationScheduler = scheduler
        scheduler.notifyAfter(SubtensorOperationResultConstants.confirmationCap)
    }

    func submit() {
        osMediator.disableScreenSleep()

        let wrapper = operationService.createSubmitWrapper(for: operation) { [weak self] in
            DispatchQueue.main.async {
                self?.startConfirmationCap()
            }
        }

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.finishSubmission(with: result)
        }
    }

    func finishSubmission(with result: Result<SubtensorStakingOperationOutcome, Error>) {
        isSubmissionFinished = true
        confirmationScheduler?.cancel()
        osMediator.enableScreenSleep()

        switch result {
        case let .success(outcome):
            presenter?.didReceiveSubmission(result: .success(outcome))
        case let .failure(error):
            let failure = error as? SubtensorStakingSubmissionFailure ??
                SubtensorStakingSubmissionFailure(stage: .unconfirmed(extrinsicHash: nil), error: error)

            presenter?.didReceiveSubmission(result: .failure(failure))
        }
    }

    func provideExpectedBlockTime() {
        execute(
            wrapper: chainFactory.createExpectedBlockTimeWrapper(),
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(blockTime):
                self?.presenter?.didReceiveExpectedBlockTime(blockTime)
            case let .failure(error):
                self?.logger.warning("Expected block time unavailable: \(error)")
            }
        }
    }

    func provideSubnetData() {
        guard loadsSubnetData else {
            return
        }

        if !seed.isFresh {
            execute(
                wrapper: catalogueService.createCatalogueWrapper(),
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(catalogue):
                    self?.presenter?.didReceiveCatalogue(catalogue)
                case let .failure(error):
                    self?.logger.error("Subtensor catalogue unavailable for the result: \(error)")
                    self?.presenter?.didReceiveCatalogue(nil)
                }
            }
        }

        execute(
            wrapper: subnetLogosProvider.createLogosWrapper(),
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            if case let .success(logos) = result {
                self?.presenter?.didReceiveSubnetLogos(logos)
            }
        }
    }
}

extension SubtensorOperationResultInteractor: SubtensorResultInteractorInputProtocol {
    func cachedCatalogue() -> HTTPCachePeek<SubtensorSubnetCatalogue> {
        seed = loadsSubnetData ? catalogueService.cachedCatalogue() : .miss

        return seed
    }

    func setup() {
        applicationHandler.delegate = self

        provideExpectedBlockTime()
        provideSubnetData()
        submit()
    }

    func fetchBlockTimestamp(at blockHash: BlockHash) {
        execute(
            wrapper: chainFactory.createBlockTimestampWrapper(at: blockHash),
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(date):
                self?.presenter?.didReceiveBlockTimestamp(date, at: blockHash)
            case let .failure(error):
                self?.logger.warning("Block timestamp unavailable: \(error)")
            }
        }
    }

    func fetchRootHoldRemainingBlocks(for hotkeys: [AccountId]) {
        execute(
            wrapper: chainFactory.createRootHoldRemainingBlocksWrapper(coldkey: coldkey, hotkeys: hotkeys),
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(blocks):
                self?.presenter?.didReceiveRootHoldRemainingBlocks(blocks)
            case let .failure(error):
                self?.logger.warning("Root hold unavailable: \(error)")
            }
        }
    }

    func refreshPositions() {
        positionsSyncService?.refresh()
    }
}

extension SubtensorOperationResultInteractor: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !isSubmissionFinished else {
                return
            }

            osMediator.enableScreenSleep()
            presenter?.didReachConfirmationCap()
        }
    }
}

extension SubtensorOperationResultInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        presenter?.didBecomeActive()
    }
}
