import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorUnstakeSetupInteractor: SubtensorBaseInteractor {
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
    let directoryOperationFactory: SubtensorValidatorDirectoryOperationFactoryProtocol

    private let validatorCallStore = CancellableCallStore()
    private let validatorsCallStore = CancellableCallStore()
    private let subnetsInfoCallStore = CancellableCallStore()
    private let groupHotkeysCallStore = CancellableCallStore()

    override init(
        flowServices: SubtensorFlowServices,
        state: SubtensorSharedStateProtocol,
        logger: LoggerProtocol
    ) {
        subnetsOperationFactory = state.subnetsOperationFactory
        validatorPresetOperationFactory = state.earnServices.validatorPresetOperationFactory
        groupHotkeyOperationFactory = state.earnServices.groupHotkeyOperationFactory
        directoryOperationFactory = state.earnServices.validatorDirectoryOperationFactory

        super.init(flowServices: flowServices, state: state, logger: logger)
    }

    deinit {
        validatorCallStore.cancel()
        validatorsCallStore.cancel()
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

    func loadValidators(_ hotkeys: [AccountId], on subnet: SubtensorSubnetRef) {
        validatorsCallStore.cancel()

        executeCancellable(
            wrapper: directoryOperationFactory.createListedDetailsWrapper(for: hotkeys, subnet: subnet),
            inOperationQueue: operationQueue,
            backingCallIn: validatorsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(validators):
                self?.presenter?.didReceiveValidators(validators, hotkeys: hotkeys)
            case let .failure(error):
                self?.logger.warning("Subtensor unstake validators unavailable: \(error)")
                self?.presenter?.didFailValidators(for: hotkeys)
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
