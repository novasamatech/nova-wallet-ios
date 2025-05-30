import UIKit
import Operation_iOS
import SubstrateSdk

final class GenericLedgerWalletInteractor {
    weak var presenter: GenericLedgerWalletInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let deviceId: UUID
    let ledgerApplication: GenericLedgerPolkadotApplicationProtocol
    let model: GenericLedgerWalletConfirmModel
    let operationQueue: OperationQueue

    init(
        ledgerApplication: GenericLedgerPolkadotApplicationProtocol,
        deviceId: UUID,
        model: GenericLedgerWalletConfirmModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.deviceId = deviceId
        self.ledgerApplication = ledgerApplication
        self.model = model
        self.operationQueue = operationQueue
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .main
        ) { [weak self] changes in
            let actualChanges: [DataProviderChange<ChainModel>] = changes.compactMap { change in
                switch change {
                case let .insert(item):
                    return item.supportsGenericLedgerApp ? .insert(newItem: item) : nil
                case let .update(item):
                    return item.supportsGenericLedgerApp ?
                        .update(newItem: item) :
                        .delete(deletedIdentifier: item.identifier)
                case let .delete(identifier):
                    return .delete(deletedIdentifier: identifier)
                }
            }

            self?.presenter?.didReceiveChains(changes: actualChanges)
        }
    }
}

private extension GenericLedgerWalletInteractor {
    func createSubstrateWrapper(_ shouldConfirm: Bool) -> CompoundOperationWrapper<LedgerSubstrateAccountResponse> {
        ledgerApplication.getGenericSubstrateAccountWrapperBy(
            deviceId: deviceId,
            index: model.index,
            displayVerificationDialog: shouldConfirm
        )
    }

    func createEvmWrapper(_ shouldConfirm: Bool) -> CompoundOperationWrapper<LedgerEvmAccountResponse?> {
        guard model.schemes.contains(.evm) else {
            return .createWithResult(nil)
        }

        let wrapper = ledgerApplication.getGenericEvmAccountWrapperBy(
            deviceId: deviceId,
            index: model.index,
            displayVerificationDialog: shouldConfirm
        )

        let mappingOperation = ClosureOperation<LedgerEvmAccountResponse?> {
            try wrapper.targetOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: mappingOperation)
    }

    func createModelWrapper(_ shouldConfirm: Bool) -> CompoundOperationWrapper<PolkadotLedgerWalletModel> {
        let substrateWrapper = createSubstrateWrapper(shouldConfirm)
        let evmWrapper = createEvmWrapper(shouldConfirm)

        evmWrapper.addDependency(wrapper: substrateWrapper)

        let mappingOperation = ClosureOperation<PolkadotLedgerWalletModel> {
            let substrateResponse = try substrateWrapper.targetOperation.extractNoCancellableResultData()
            let evmModel = try evmWrapper.targetOperation.extractNoCancellableResultData()

            let substrate = try PolkadotLedgerWalletModel.Substrate(
                substrateResponse: substrateResponse
            )

            let evm = try evmModel.map { model in
                try PolkadotLedgerWalletModel.EVM(evmResponse: model)
            }

            return PolkadotLedgerWalletModel(substrate: substrate, evm: evm)
        }

        mappingOperation.addDependency(evmWrapper.targetOperation)

        return evmWrapper
            .insertingHead(operations: substrateWrapper.allOperations)
            .insertingTail(operation: mappingOperation)
    }
}

extension GenericLedgerWalletInteractor: GenericLedgerWalletInteractorInputProtocol {
    func setup() {
        subscribeChains()
        fetchAccount()
    }

    func fetchAccount() {
        let wrapper = createModelWrapper(false)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(model):
                self?.presenter?.didReceive(model: model)
            case let .failure(error):
                self?.presenter?.didReceive(error: .fetchAccount(error))
            }
        }
    }

    func confirmAccount() {
        let wrapper = createModelWrapper(true)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didReceiveAccountConfirmation()
            case let .failure(error):
                self?.presenter?.didReceive(error: .confirmAccount(error))
            }
        }
    }

    func cancelRequest() {
        ledgerApplication.connectionManager.cancelRequest(for: deviceId)
    }
}
