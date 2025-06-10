import Foundation
import Operation_iOS

protocol MultisigPendingOperationsSyncServiceProtocol {}

class MultisigPendingOperationsSyncService {
    let walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol

    private let mutex = NSLock()

    private let pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol
    private let remoteCallDataFactory: SubqueryMultisigsOperationFactoryProtocol

    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let chainRegistry: ChainRegistryProtocol
    private let delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let logger: LoggerProtocol?
    private let storageFacade: StorageFacadeProtocol

    private let cancellableSyncStore = CancellableCallStore()

    private var multisigOperationsSubscriptions: [AccountId: MultisigPendingOperationsSubscription] = [:]
    private var pendingOperations: [CallHash: Multisig.PendingOperation] = [:]

    private var metaAccountsDataProvider: StreamableProvider<ManagedMetaAccountModel>?

    private var multisigMetaAccounts: [MetaAccountModel] = [] {
        didSet {
            if multisigMetaAccounts != oldValue {
                updatePendingOperationsSubscriptions()
            }
        }
    }

    init(
        chainRegistry: ChainRegistryProtocol,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        delegatedAccountSyncService: DelegatedAccountSyncServiceProtocol,
        storageFacade: StorageFacadeProtocol,
        pendingCallHashesOperationFactory: MultisigStorageOperationFactoryProtocol,
        remoteCallDataFactory: SubqueryMultisigsOperationFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.chainRegistry = chainRegistry
        self.chainRepository = chainRepository
        self.delegatedAccountSyncService = delegatedAccountSyncService
        self.storageFacade = storageFacade
        self.pendingCallHashesOperationFactory = pendingCallHashesOperationFactory
        self.remoteCallDataFactory = remoteCallDataFactory
        self.walletListLocalSubscriptionFactory = walletListLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger

        setup()
    }

    deinit {
        clearAllSubscriptions()
    }
}

// MARK: - Private

private extension MultisigPendingOperationsSyncService {
    func setup() {
        metaAccountsDataProvider = subscribeAllWalletsProvider()
    }

    func updatePendingOperationsSubscriptions() {
        let chainsFetchOperation = chainRepository.fetchAllOperation(with: .init())

        let fetchCallHashesOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            return multisigMetaAccounts.map { multisig in
                self.createPendingOperationsWrapper(
                    for: multisig,
                    dependingOn: chainsFetchOperation
                )
            }
        }.longrunOperation()

        execute(
            operation: fetchCallHashesOperation,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableSyncStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success(dict):
                let merged = dict.reduce(into: [:]) { $0.merge($1, uniquingKeysWith: { $1 }) }

                self?.mutex.lock()

                self?.pendingOperations.merge(merged, uniquingKeysWith: { $1 })

                self?.mutex.unlock()
            case let .failure(error):
                self?.logger?.error("Failed to fetch pending operations: \(error)")
            }
        }
    }

    func createPendingOperationsWrapper(
        for multisigMetaAccount: MetaAccountModel,
        dependingOn chainsFetchOperation: BaseOperation<[ChainModel]>
    ) -> CompoundOperationWrapper<[CallHash: Multisig.PendingOperation]> {
        guard let signatory = multisigMetaAccount.multisig?.signatory else {
            return .createWithError(MultisigPendingOperationsSyncError.multisigAccountUnavailable)
        }
        let chainIdMatchOperation = createMatchChainOperation(
            for: multisigMetaAccount,
            chainsClosure: { try chainsFetchOperation.extractNoCancellableResultData() }
        )
        let callHashFetchWrapper = createCallHashFetchWrapper(
            for: multisigMetaAccount,
            chainIdClosure: { try chainIdMatchOperation.extractNoCancellableResultData() }
        )
        let callDataFetchWrapper = createCallDataFetchWrapper {
            Set(
                try callHashFetchWrapper
                    .targetOperation
                    .extractNoCancellableResultData()
                    .keys
            )
        }

        chainIdMatchOperation.addDependency(chainsFetchOperation)
        callHashFetchWrapper.targetOperation.addDependency(chainIdMatchOperation)
        callDataFetchWrapper.addDependency(wrapper: callHashFetchWrapper)

        let mapOperation = ClosureOperation<[CallHash: Multisig.PendingOperation]> {
            let chainId = try chainIdMatchOperation.extractNoCancellableResultData()
            let callHashes = try callHashFetchWrapper.targetOperation.extractNoCancellableResultData()
            let callData = try callDataFetchWrapper.targetOperation.extractNoCancellableResultData()

            return callHashes.reduce(into: [:]) { acc, keyValue in
                let matchingCallData = callData[keyValue.key]

                let pendingOperation = Multisig.PendingOperation(
                    call: nil,
                    callHash: keyValue.key,
                    signatory: signatory,
                    chainId: chainId,
                    multisigDefinition: keyValue.value
                )

                acc[keyValue.key] = pendingOperation
            }
        }

        mapOperation.addDependency(chainIdMatchOperation)
        mapOperation.addDependency(callHashFetchWrapper.targetOperation)
        mapOperation.addDependency(callDataFetchWrapper.targetOperation)

        let dependencies = [chainsFetchOperation, chainIdMatchOperation]
            + callHashFetchWrapper.allOperations
            + callDataFetchWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func createCallDataFetchWrapper(
        callHashesClosure: @escaping () throws -> Set<CallHash>
    ) -> CompoundOperationWrapper<[CallHash: CallData]> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let callHashes = try callHashesClosure()
            let callDataFetchOperation = remoteCallDataFactory.createFetchCallDataOperation(for: callHashes)

            return CompoundOperationWrapper(targetOperation: callDataFetchOperation)
        }
    }

    func createCallHashFetchWrapper(
        for multisigMetaAccount: MetaAccountModel,
        chainIdClosure: @escaping () throws -> ChainModel.Id
    ) -> CompoundOperationWrapper<[CallHash: Multisig.MultisigDefinition]> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let chainId = try chainIdClosure()

            guard let connection = chainRegistry.getConnection(for: chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            guard let multisigAccountId = multisigMetaAccount.multisig?.accountId else {
                throw MultisigPendingOperationsSyncError.multisigAccountUnavailable
            }

            return pendingCallHashesOperationFactory.fetchPendingOperations(
                for: multisigAccountId,
                connection: connection,
                runtimeProvider: runtimeProvider
            )
        }
    }

    func createMatchChainOperation(
        for multisigMetaAccount: MetaAccountModel,
        chainsClosure: @escaping () throws -> [ChainModel]
    ) -> BaseOperation<ChainModel.Id> {
        ClosureOperation {
            let chains = try chainsClosure()

            let accountRequests = chains.map { $0.accountRequest() }
            let accountResponse = accountRequests.compactMap { multisigMetaAccount.fetch(for: $0) }.first

            guard let accountResponse else {
                throw MultisigPendingOperationsSyncError.noChainMatchingMultisigAccount
            }

            return accountResponse.chainId
        }
    }

    func setupSubscription(
        for multisigAccountId: AccountId,
        callHashes: Set<CallHash>,
        chainId: ChainModel.Id
    ) throws {
        clearSubscription(for: multisigAccountId)

        multisigOperationsSubscriptions[multisigAccountId] = MultisigPendingOperationsSubscription(
            accountId: multisigAccountId,
            chainId: chainId,
            callHashes: callHashes,
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationQueue: operationQueue,
            workingQueue: .init(label: "com.novawallet.multisig.updating", qos: .userInitiated)
        )
    }

    func clearSubscription(for accountId: AccountId) {
        multisigOperationsSubscriptions[accountId] = nil
    }

    func clearAllSubscriptions() {
        multisigOperationsSubscriptions = [:]
    }
}

// MARK: - MultisigPendingOperationsSyncServiceProtocol

extension MultisigPendingOperationsSyncService: MultisigPendingOperationsSyncServiceProtocol {}

// MARK: - WalletListLocalStorageSubscriber

extension MultisigPendingOperationsSyncService: WalletListLocalStorageSubscriber, WalletListLocalSubscriptionHandler {
    func handleAllWallets(result: Result<[DataProviderChange<ManagedMetaAccountModel>], Error>) {
        switch result {
        case let .success(changes):
            let mappedChanges: [DataProviderChange<MetaAccountModel>] = changes
                .compactMap { change in
                    guard change.isDeletion || change.item?.info.delegationId?.delegationType == .multisig else {
                        return nil
                    }

                    return switch change {
                    case let .insert(newItem): .insert(newItem: newItem.info)
                    case let .update(newItem): .update(newItem: newItem.info)
                    case let .delete(deletedIdentifier): .delete(deletedIdentifier: deletedIdentifier)
                    }
                }

            multisigMetaAccounts = multisigMetaAccounts.applying(changes: mappedChanges)
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}

enum MultisigPendingOperationsSyncError: Error {
    case noChainMatchingMultisigAccount
    case multisigAccountUnavailable
}
