import UIKit

final class MythosStkYourCollatorsInteractor {
    weak var presenter: MythosStkYourCollatorsInteractorOutputProtocol?

    let chain: ChainModel
    let stakingDetailsService: MythosStakingDetailsSyncServiceProtocol
    let collatorsOperationFactory: MythosStakableCollatorOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    let collatorsReqStore = CancellableCallStore()

    init(
        chain: ChainModel,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        collatorsOperationFactory: MythosStakableCollatorOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.stakingDetailsService = stakingDetailsService
        self.collatorsOperationFactory = collatorsOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        collatorsReqStore.cancel()
    }
}

private extension MythosStkYourCollatorsInteractor {
    func makeDetailsSubscription() {
        stakingDetailsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            if let newState {
                self?.provideCollators()
                self?.presenter?.didReceiveStakingDetails(newState)
            }
        }
    }

    func provideCollators() {
        collatorsReqStore.cancel()

        let collatorIds = stakingDetailsService.currentDetails?.collatorIds ?? []
        guard !collatorIds.isEmpty else {
            presenter?.didReceiveCollators([])
            return
        }

        let wrapper = collatorsOperationFactory.createSelectedCollatorsWrapper(Array(collatorIds))

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: collatorsReqStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(collators):
                self?.presenter?.didReceiveCollators(collators)
            case let .failure(error):
                self?.logger.debug("Collators error: \(error)")
            }
        }
    }
}

extension MythosStkYourCollatorsInteractor: MythosStkYourCollatorsInteractorInputProtocol {
    func setup() {
        makeDetailsSubscription()

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func retry() {
        provideCollators()
    }
}

extension MythosStkYourCollatorsInteractor: EventVisitorProtocol {
    func processEraStakersInfoChanged(event: EraStakersInfoChanged) {
        guard chain.chainId == event.chainId else { return }

        provideCollators()
    }
}
