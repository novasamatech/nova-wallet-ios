import Foundation
import Operation_iOS

protocol MultisigOperationsLocalSubscriptionFactoryProtocol {
    func getPendingOperatonsProvider(
        for multisigAccountId: AccountId,
        chainId: ChainModel.Id?
    ) throws -> StreamableProvider<Multisig.PendingOperation>

    func getPendingOperatonProvider(
        identifier: String
    ) throws -> StreamableProvider<Multisig.PendingOperation>
}

final class MultisigOperationsLocalSubscriptionFactory: BaseLocalSubscriptionFactory {
    static let shared = MultisigOperationsLocalSubscriptionFactory(
        storageFacade: SubstrateDataStorageFacade.shared,
        operationManager: OperationManagerFacade.sharedManager,
        logger: Logger.shared
    )

    let storageFacade: StorageFacadeProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.operationManager = operationManager
        self.logger = logger
    }
}

extension MultisigOperationsLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol {
    func getPendingOperatonsProvider(
        for multisigAccountId: AccountId,
        chainId: ChainModel.Id?
    ) throws -> StreamableProvider<Multisig.PendingOperation> {
        clearIfNeeded()

        let cacheKey = [
            "multisigPendingOperations",
            "\(multisigAccountId.toHexString())",
            "\(chainId ?? "anyChain")"
        ].joined(with: .dash)

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<Multisig.PendingOperation> {
            return provider
        }

        let source = EmptyStreamableSource<Multisig.PendingOperation>()

        let mapper = MultisigPendingOperationMapper()

        let predicate = if let chainId {
            NSPredicate.pendingMultisigOperations(
                for: chainId,
                multisigAccountId: multisigAccountId
            )
        } else {
            NSPredicate.pendingMultisigOperations(multisigAccountId: multisigAccountId)
        }

        let repository = storageFacade.createRepository(
            filter: predicate,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                if let chainId {
                    entity.multisigAccountId == multisigAccountId.toHex() &&
                        entity.chainId == chainId
                } else {
                    entity.multisigAccountId == multisigAccountId.toHex()
                }
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }

    func getPendingOperatonProvider(
        identifier: String
    ) throws -> StreamableProvider<Multisig.PendingOperation> {
        clearIfNeeded()

        let cacheKey = [
            "multisigPendingOperations",
            identifier
        ].joined(with: .dash)

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<Multisig.PendingOperation> {
            return provider
        }

        let source = EmptyStreamableSource<Multisig.PendingOperation>()

        let mapper = MultisigPendingOperationMapper()

        let predicate = NSPredicate.pendingOperation(identifier: identifier)

        let repository = storageFacade.createRepository(
            filter: predicate,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                entity.identifier == identifier
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }
}
