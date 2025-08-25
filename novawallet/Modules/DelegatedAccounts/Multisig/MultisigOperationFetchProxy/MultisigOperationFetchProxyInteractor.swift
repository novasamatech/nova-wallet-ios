import Foundation
import Operation_iOS

final class MultisigOperationFetchProxyInteractor {
    weak var presenter: MultisigOperationFetchProxyInteractorOutputProtocol?

    let operationKey: Multisig.PendingOperation.Key

    let pendingOperationFetchFactory: PendingMultisigRemoteFetchFactoryProtocol
    let pendingOperationProvider: MultisigOperationProviderProxyProtocol
    let pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    let callStore = CancellableCallStore()

    init(
        operationKey: Multisig.PendingOperation.Key,
        pendingOperationFetchFactory: PendingMultisigRemoteFetchFactoryProtocol,
        pendingOperationProviderProxy: MultisigOperationProviderProxyProtocol,
        pendingOperationsRepository: AnyDataProviderRepository<Multisig.PendingOperation>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operationKey = operationKey
        self.pendingOperationFetchFactory = pendingOperationFetchFactory
        pendingOperationProvider = pendingOperationProviderProxy
        self.pendingOperationsRepository = pendingOperationsRepository
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        callStore.cancel()
    }
}

// MARK: - Private

private extension MultisigOperationFetchProxyInteractor {
    func createUpdateWrapper() -> CompoundOperationWrapper<Multisig.PendingOperation?> {
        let pendingOperationsWrapper = pendingOperationFetchFactory.createFetchWrapper()

        let saveOperation = pendingOperationsRepository.saveOperation(
            {
                let operations = try pendingOperationsWrapper.targetOperation.extractNoCancellableResultData()

                guard let operation = operations[self.operationKey] else { return [] }

                return [operation]
            },
            {
                let operations = try pendingOperationsWrapper.targetOperation.extractNoCancellableResultData()

                guard operations[self.operationKey] == nil else { return [] }

                return [self.operationKey.stringValue()]
            }
        )

        saveOperation.addDependency(pendingOperationsWrapper.targetOperation)

        let resultOperation = ClosureOperation<Multisig.PendingOperation?> { [weak self] in
            guard let self else { return nil }
            let operations = try pendingOperationsWrapper.targetOperation.extractNoCancellableResultData()

            guard let operation = operations[operationKey] else { return nil }

            pendingOperationProvider.subscribePendingOperation(
                identifier: operation.identifier,
                handler: self
            )

            return operation
        }

        resultOperation.addDependency(saveOperation)

        return pendingOperationsWrapper
            .insertingTail(operation: saveOperation)
            .insertingTail(operation: resultOperation)
    }
}

// MARK: - MultisigOperationFetchProxyInteractorInputProtocol

extension MultisigOperationFetchProxyInteractor: MultisigOperationFetchProxyInteractorInputProtocol {
    func setup() {
        presenter?.didReceiveOperation(nil)

        let wrapper = createUpdateWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(operation):
                guard operation == nil else { return }

                self?.presenter?.didReceiveError(.onChainOperationNotFound)
            case let .failure(error):
                self?.presenter?.didReceiveError(.common(error))
                self?.logger.error("Failed to fetch pending operations: \(error)")
            }
        }
    }
}

// MARK: - MultisigOperationProviderHandlerProtocol

extension MultisigOperationFetchProxyInteractor: MultisigOperationProviderHandlerProtocol {
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

// MARK: - Errors

enum MultisigOperationFetchProxyError: Error {
    case onChainOperationNotFound
    case common(Error)
}
