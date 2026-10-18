import Foundation
import Foundation_iOS
import Operation_iOS

final class SubtensorOperationResultInteractor: SubtensorLoadDelivering {
    weak var presenter: SubtensorOperationResultInteractorOutputProtocol?

    let operation: SubtensorStakingOperation
    let coldkey: AccountId
    let loadsSubnetData: Bool
    let submissionOperationFactory: SubtensorStakingSubmissionOperationFactoryProtocol
    let chainOperationFactory: SubtensorOperationResultChainOperationFactoryProtocol
    let catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let osMediator: OperatingSystemMediating
    let schedulerFactory: (SchedulerDelegate) -> SchedulerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let catalogueStore = CancellableCallStore()
    private var confirmationScheduler: SchedulerProtocol?
    private var isSubmissionFinished = false

    init(
        operation: SubtensorStakingOperation,
        coldkey: AccountId,
        loadsSubnetData: Bool,
        submissionOperationFactory: SubtensorStakingSubmissionOperationFactoryProtocol,
        chainOperationFactory: SubtensorOperationResultChainOperationFactoryProtocol,
        catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        osMediator: OperatingSystemMediating,
        schedulerFactory: @escaping (SchedulerDelegate) -> SchedulerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operation = operation
        self.coldkey = coldkey
        self.loadsSubnetData = loadsSubnetData
        self.submissionOperationFactory = submissionOperationFactory
        self.chainOperationFactory = chainOperationFactory
        self.catalogueOperationFactory = catalogueOperationFactory
        self.subnetLogosProvider = subnetLogosProvider
        self.osMediator = osMediator
        self.schedulerFactory = schedulerFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        catalogueStore.cancel()
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

        let wrapper = submissionOperationFactory.createSubmitWrapper(for: operation) { [weak self] in
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

    func provideSubnetData() {
        guard loadsSubnetData else {
            return
        }

        let catalogueOperationFactory = catalogueOperationFactory

        load(
            catalogueOperationFactory.createCatalogueWrapper(),
            cached: { catalogueOperationFactory.cachedCatalogue().value },
            in: catalogueStore,
            label: "catalogue for the result",
            deliver: { [weak self] in
                self?.presenter?.didReceiveCatalogue($0)
            }
        )

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

extension SubtensorOperationResultInteractor: SubtensorOperationResultInteractorInputProtocol {
    func setup() {
        provideSubnetData()
        submit()
    }

    func fetchBlockTimestamp(at blockHash: BlockHash) {
        execute(
            wrapper: chainOperationFactory.createBlockTimestampWrapper(at: blockHash),
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
            wrapper: chainOperationFactory.createRootHoldRemainingBlocksWrapper(coldkey: coldkey, hotkeys: hotkeys),
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
