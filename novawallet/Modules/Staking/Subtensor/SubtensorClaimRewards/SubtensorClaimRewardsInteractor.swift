import UIKit
import Operation_iOS

final class SubtensorClaimRewardsInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorClaimInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorClaimInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let rootClaimableService: SubtensorRootClaimableServiceProtocol
    let claimableFetchFactory: SubtensorRootClaimableFetching

    private let snapshotCallStore = CancellableCallStore()

    init(
        flowServices: SubtensorFlowServices,
        state: SubtensorStakingSharedStateProtocol,
        claimableFetchFactory: SubtensorRootClaimableFetching,
        logger: LoggerProtocol
    ) {
        rootClaimableService = flowServices.rootClaimableService
        self.claimableFetchFactory = claimableFetchFactory

        super.init(flowServices: flowServices, state: state, logger: logger)
    }

    deinit {
        snapshotCallStore.cancel()

        rootClaimableService.remove(observer: self)
    }

    override func onSetup() {
        rootClaimableService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveClaimable(newState)
        }
    }
}

extension SubtensorClaimRewardsInteractor: SubtensorClaimInteractorInputProtocol {
    func refreshClaimSnapshot() {
        snapshotCallStore.cancel()

        executeCancellable(
            wrapper: claimableFetchFactory.createLatestClaimableWrapper(for: selectedAccount.accountId),
            inOperationQueue: operationQueue,
            backingCallIn: snapshotCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(claimable):
                self?.presenter?.didReceiveClaimSnapshot(claimable)
            case let .failure(error):
                self?.presenter?.didFailClaimSnapshot(error)
            }
        }
    }
}
