import Foundation
import Operation_iOS

protocol MultisigOperationProviderProxyProtocol: AnyObject {
    var handler: MultisigOperationProviderHandlerProtocol? { get set }

    func subscribePendingOperations(
        for accountId: AccountId,
        chainId: ChainModel.Id?
    )

    func subscribePendingOperation(
        identifier: String
    )
}

protocol MultisigOperationProviderHandlerProtocol: AnyObject {
    func handleMultisigPendingOperations(
        result: Result<[DataProviderChange<Multisig.PendingOperationProxyModel>], Error>
    )

    func handleMultisigPendingOperation(
        result: Result<Multisig.PendingOperationProxyModel?, Error>,
        identifier: String
    )
}

extension MultisigOperationProviderHandlerProtocol {
    func handleMultisigPendingOperations(
        result _: Result<[DataProviderChange<Multisig.PendingOperationProxyModel>], Error>
    ) {}

    func handleMultisigPendingOperation(
        result _: Result<Multisig.PendingOperationProxyModel?, Error>,
        identifier _: String
    ) {}
}

final class MultisigOperationProviderProxy {
    let callFormattingFactory: CallFormattingOperationFactoryProtocol
    let operationQueue: OperationQueue
    let pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol

    weak var handler: MultisigOperationProviderHandlerProtocol?

    private var formattingCache = InMemoryCache<Substrate.CallHash, FormattedCall>()

    private var provider: StreamableProvider<Multisig.PendingOperation>?

    private var pendingCallStore: CancellableCallStore?

    init(
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol,
        callFormattingFactory: CallFormattingOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.pendingMultisigLocalSubscriptionFactory = pendingMultisigLocalSubscriptionFactory
        self.callFormattingFactory = callFormattingFactory
        self.operationQueue = operationQueue
    }
}

private extension MultisigOperationProviderProxy {
    func createChangesProcessingWrapper(
        _ changes: [DataProviderChange<Multisig.PendingOperation>]
    ) -> CompoundOperationWrapper<[DataProviderChange<Multisig.PendingOperationProxyModel>]> {
        let changesWrappers = changes.map { change in
            switch change {
            case let .insert(newItem):
                createChangeProcessingWrapper(for: newItem, isInsert: true)

            case let .update(newItem):
                createChangeProcessingWrapper(for: newItem, isInsert: false)

            case let .delete(deletedIdentifier):
                CompoundOperationWrapper.createWithResult(
                    DataProviderChange<Multisig.PendingOperationProxyModel>.delete(
                        deletedIdentifier: deletedIdentifier
                    )
                )
            }
        }

        let mappingOperation = ClosureOperation<[DataProviderChange<Multisig.PendingOperationProxyModel>]> {
            try changesWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }
        }

        changesWrappers.forEach { mappingOperation.addDependency($0.targetOperation) }

        let dependencies = changesWrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    func createChangeProcessingWrapper(
        for pendingOperation: Multisig.PendingOperation,
        isInsert: Bool
    ) -> CompoundOperationWrapper<DataProviderChange<Multisig.PendingOperationProxyModel>> {
        let processingWrapper = createOperationProcessingWrapper(for: pendingOperation)

        let mapOperation = ClosureOperation<DataProviderChange<Multisig.PendingOperationProxyModel>> {
            let model = try processingWrapper.targetOperation.extractNoCancellableResultData()

            return isInsert ? .insert(newItem: model) : .update(newItem: model)
        }

        mapOperation.addDependency(processingWrapper.targetOperation)

        return processingWrapper.insertingTail(operation: mapOperation)
    }

    func createOperationProcessingWrapper(
        for pendingOperation: Multisig.PendingOperation
    ) -> CompoundOperationWrapper<Multisig.PendingOperationProxyModel> {
        if let formattedModel = formattingCache.fetchValue(for: pendingOperation.callHash) {
            let model = Multisig.PendingOperationProxyModel(
                operation: pendingOperation,
                formattedModel: formattedModel
            )

            return .createWithResult(model)
        }

        guard let callData = pendingOperation.call else {
            let model = Multisig.PendingOperationProxyModel(
                operation: pendingOperation,
                formattedModel: nil
            )

            return .createWithResult(model)
        }

        let formattingWrapper = callFormattingFactory.createFormattingWrapper(
            for: callData,
            chainId: pendingOperation.chainId
        )

        let mappingOperation = ClosureOperation<Multisig.PendingOperationProxyModel> {
            let formattedModel = try? formattingWrapper.targetOperation.extractNoCancellableResultData()

            if let formattedModel {
                self.formattingCache.store(value: formattedModel, for: pendingOperation.callHash)
            }

            return Multisig.PendingOperationProxyModel(
                operation: pendingOperation,
                formattedModel: formattedModel
            )
        }

        mappingOperation.addDependency(formattingWrapper.targetOperation)

        return formattingWrapper.insertingTail(operation: mappingOperation)
    }
}

extension MultisigOperationProviderProxy: MultisigOperationProviderProxyProtocol {
    func subscribePendingOperations(
        for accountId: AccountId,
        chainId: ChainModel.Id?
    ) {
        guard provider == nil else {
            return
        }

        provider = subscribePendingOperations(for: accountId, chainId: chainId)
    }

    func subscribePendingOperation(
        identifier: String
    ) {
        guard provider == nil else {
            return
        }

        provider = subscribePendingOperation(identifier: identifier)
    }
}

extension MultisigOperationProviderProxy: MultisigOperationsLocalStorageSubscriber,
    MultisigOperationsLocalSubscriptionHandler {
    func handleMultisigPendingOperations(
        result: Result<[DataProviderChange<Multisig.PendingOperation>], Error>
    ) {
        switch result {
        case let .success(changes):
            let processingWrapper = createChangesProcessingWrapper(changes)

            let newCallStore = CancellableCallStore()

            pendingCallStore?.addDependency(to: processingWrapper)
            pendingCallStore = newCallStore

            executeCancellable(
                wrapper: processingWrapper,
                inOperationQueue: operationQueue,
                backingCallIn: newCallStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(changes):
                    self?.handler?.handleMultisigPendingOperations(
                        result: .success(changes)
                    )
                case let .failure(error):
                    self?.handler?.handleMultisigPendingOperations(
                        result: .failure(error)
                    )
                }
            }
        case let .failure(error):
            handler?.handleMultisigPendingOperations(result: .failure(error))
        }
    }

    func handleMultisigPendingOperation(
        result: Result<Multisig.PendingOperation?, Error>,
        identifier: String
    ) {
        switch result {
        case let .success(pendingOperation):
            guard let pendingOperation else {
                handler?.handleMultisigPendingOperation(
                    result: .success(nil),
                    identifier: identifier
                )
                return
            }

            let processingWrapper = createOperationProcessingWrapper(for: pendingOperation)

            let newCallStore = CancellableCallStore()

            pendingCallStore?.addDependency(to: processingWrapper)
            pendingCallStore = newCallStore

            executeCancellable(
                wrapper: processingWrapper,
                inOperationQueue: operationQueue,
                backingCallIn: newCallStore,
                runningCallbackIn: .main
            ) { [weak self] result in
                switch result {
                case let .success(formattedOperation):
                    self?.handler?.handleMultisigPendingOperation(
                        result: .success(formattedOperation),
                        identifier: identifier
                    )
                case let .failure(error):
                    self?.handler?.handleMultisigPendingOperation(
                        result: .failure(error),
                        identifier: identifier
                    )
                }
            }
        case let .failure(error):
            handler?.handleMultisigPendingOperation(
                result: .failure(error),
                identifier: identifier
            )
        }
    }
}
