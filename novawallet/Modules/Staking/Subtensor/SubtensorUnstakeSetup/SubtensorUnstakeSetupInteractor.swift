import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorUnstakeSetupInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorUnstakeSetupInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorUnstakeSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let subnetsOperationFactory: SubtensorSubnetsOperationFactoryProtocol
    let validatorPresetOperationFactory: SubtensorValidatorPresetOperationFactoryProtocol
    let groupHotkeyOperationFactory: SubtensorGroupHotkeyOperationFactoryProtocol

    private let validatorCallStore = CancellableCallStore()
    private let subnetsInfoCallStore = CancellableCallStore()
    private let groupHotkeysCallStore = CancellableCallStore()

    override init(
        flowServices: SubtensorFlowServices,
        state: SubtensorStakingSharedStateProtocol,
        logger: LoggerProtocol
    ) {
        subnetsOperationFactory = state.subnetsOperationFactory
        validatorPresetOperationFactory = state.earnServices.validatorPresetOperationFactory
        groupHotkeyOperationFactory = state.earnServices.groupHotkeyOperationFactory

        super.init(flowServices: flowServices, state: state, logger: logger)
    }

    deinit {
        validatorCallStore.cancel()
        subnetsInfoCallStore.cancel()
        groupHotkeysCallStore.cancel()
    }
}

extension SubtensorUnstakeSetupInteractor: SubtensorUnstakeSetupInteractorInputProtocol {
    func loadSubnetsInfo(for netuid: UInt16) {
        subnetsInfoCallStore.cancel()

        executeCancellable(
            wrapper: subnetsOperationFactory.createSubnetInfoWrapper(for: netuid),
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
            wrapper: validatorPresetOperationFactory.createLockedWrapper(for: hotkey, subnet: subnet),
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

    func loadGroupHotkeys(_ hotkeys: [AccountId], netuid: UInt16) {
        groupHotkeysCallStore.cancel()

        executeCancellable(
            wrapper: groupHotkeyOperationFactory.createInfoWrapper(
                coldkey: selectedAccount.accountId,
                hotkeys: hotkeys,
                netuid: netuid
            ),
            inOperationQueue: operationQueue,
            backingCallIn: groupHotkeysCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceiveGroupHotkeys(info)
            case let .failure(error):
                self?.logger.warning("Subtensor unstake group hotkeys unavailable: \(error)")
            }
        }
    }
}
