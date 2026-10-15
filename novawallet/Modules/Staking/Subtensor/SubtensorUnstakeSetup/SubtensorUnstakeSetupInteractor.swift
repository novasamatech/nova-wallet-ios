import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorUnstakeSetupInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorUnstakeInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorUnstakeInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let subnetsService: SubtensorSubnetsServiceProtocol
    let validatorFactory: SubtensorValidatorPresetFactoryProtocol
    let rootHoldFactory: SubtensorRootHoldFactoryProtocol

    private let validatorCallStore = CancellableCallStore()
    private let holdsCallStore = CancellableCallStore()
    private let subnetsInfoCallStore = CancellableCallStore()

    init(
        flowServices: SubtensorFlowServices,
        state: SubtensorStakingSharedStateProtocol,
        validatorFactory: SubtensorValidatorPresetFactoryProtocol,
        logger: LoggerProtocol
    ) {
        subnetsService = state.subnetsService
        self.validatorFactory = validatorFactory
        rootHoldFactory = state.earnServices.rootHoldFactory

        super.init(flowServices: flowServices, state: state, logger: logger)
    }

    deinit {
        validatorCallStore.cancel()
        holdsCallStore.cancel()
        subnetsInfoCallStore.cancel()
    }
}

extension SubtensorUnstakeSetupInteractor: SubtensorUnstakeInteractorInputProtocol {
    func loadSubnetsInfo() {
        subnetsInfoCallStore.cancel()

        executeCancellable(
            wrapper: subnetsService.createSubnetsInfoWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: subnetsInfoCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceiveSubnetsInfo(info)
            case let .failure(error):
                self?.presenter?.didReceiveSubnetsInfoError(error)
            }
        }
    }

    func loadValidator(_ hotkey: AccountId, on subnet: SubtensorSubnetRef) {
        validatorCallStore.cancel()

        executeCancellable(
            wrapper: validatorFactory.createLockedWrapper(for: hotkey, subnet: subnet),
            inOperationQueue: operationQueue,
            backingCallIn: validatorCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(validator):
                self?.presenter?.didReceiveValidator(validator, hotkey: hotkey)
            case let .failure(error):
                self?.logger.warning("Subtensor unstake validator unavailable: \(error)")
                self?.presenter?.didReceiveValidator(nil, hotkey: hotkey)
            }
        }
    }

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
                self?.logger.warning("Subtensor root holds unavailable for the unstake: \(error)")
            }
        }
    }
}
