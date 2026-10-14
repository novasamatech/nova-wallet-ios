import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorConfirmInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let rootHoldFactory: SubtensorRootHoldFactoryProtocol

    private let holdsCallStore = CancellableCallStore()

    override init(
        flowServices: SubtensorFlowServices,
        state: SubtensorStakingSharedStateProtocol,
        logger: LoggerProtocol
    ) {
        rootHoldFactory = state.earnServices.rootHoldFactory

        super.init(flowServices: flowServices, state: state, logger: logger)
    }

    deinit {
        holdsCallStore.cancel()
    }
}

extension SubtensorConfirmInteractor: SubtensorConfirmInteractorInputProtocol {
    func loadRootHolds(for hotkeys: [AccountId]) {
        holdsCallStore.cancel()

        executeCancellable(
            wrapper: rootHoldFactory.createHoldsWrapper(coldkey: selectedAccount.accountId, hotkeys: hotkeys),
            inOperationQueue: operationQueue,
            backingCallIn: holdsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(holds):
                self?.presenter?.didReceiveRootHolds(holds)
            case let .failure(error):
                self?.logger.warning("Subtensor root holds unavailable for the unstake confirm: \(error)")
            }
        }
    }
}
