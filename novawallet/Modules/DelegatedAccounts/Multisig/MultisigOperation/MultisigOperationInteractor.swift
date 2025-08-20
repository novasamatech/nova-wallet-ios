import Foundation

final class MultisigOperationInteractor {
    weak var presenter: MultisigOperationInteractorOutputProtocol?

    let input: MultisigOperationModuleInput

    let pendingOperationProvider: MultisigOperationProviderProxyProtocol
    let logger: LoggerProtocol

    init(
        input: MultisigOperationModuleInput,
        pendingOperationProvider: MultisigOperationProviderProxyProtocol,
        logger: LoggerProtocol
    ) {
        self.input = input
        self.pendingOperationProvider = pendingOperationProvider
        self.logger = logger
    }
}

// MARK: - MultisigOperationInteractorInputProtocol

extension MultisigOperationInteractor: MultisigOperationInteractorInputProtocol {
    func setup() {
        switch input {
        case let .operation(operation):
            presenter?.didReceiveOperation(operation)
        case let .key(operationKey):
            presenter?.didReceiveOperation(nil)

            pendingOperationProvider.subscribePendingOperation(
                identifier: operationKey.stringValue(),
                handler: self
            )
        }
    }
}

// MARK: - MultisigOperationProviderHandlerProtocol

extension MultisigOperationInteractor: MultisigOperationProviderHandlerProtocol {
    func handleMultisigPendingOperation(
        result: Result<Multisig.PendingOperationProxyModel?, Error>,
        identifier _: String
    ) {
        switch result {
        case let .success(item):
            presenter?.didReceiveOperation(item)
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
        }
    }
}
