import UIKit

final class MythosStkYourCollatorsInteractor {
    weak var presenter: MythosStkYourCollatorsInteractorOutputProtocol?

    let chain: ChainModel
    let stakingDetailsService: MythosStakingDetailsSyncServiceProtocol
    let collatorsOperationFactory: MythosStakableCollatorOperationFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue

    let collatorsReqStore = CancellableCallStore()

    init(
        chain: ChainModel,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        collatorsOperationFactory: MythosStakableCollatorOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.stakingDetailsService = stakingDetailsService
        self.collatorsOperationFactory = collatorsOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
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
            let newDetails = newState.valueWhenDefined(else: nil)

            self?.provideCollators()
            self?.presenter?.didReceiveStakingDetails(newDetails)
        }
    }

    func provideCollators() {
        collatorsReqStore.cancel()

        let details = stakingDetailsService.currentDetails.valueWhenDefined(else: nil)
        let collatorIds = details?.collatorIds ?? []
        guard !collatorIds.isEmpty else {
            presenter?.didReceiveCollatorsResult(.success([]))
            return
        }

        let wrapper = collatorsOperationFactory.createSelectedCollatorsWrapper(Array(collatorIds))

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: collatorsReqStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceiveCollatorsResult(result)
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
