import SubstrateSdk
import RobinHood
import BigInt

final class ChainProxySyncService: ObservableSyncService, AnyCancellableCleaning {
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let proxyOperationFactory: ProxyOperationFactoryProtocol
    let chainModel: ChainModel
    let requestFactory: StorageRequestFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let eventCenter: EventCenterProtocol

    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private var pendingCall = CancellableCallStore()
    private let changesCalculator: ChainProxyChangesCalculator

    init(
        chainModel: ChainModel,
        metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        chainRegistry: ChainRegistryProtocol,
        proxyOperationFactory: ProxyOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue
    ) {
        self.chainModel = chainModel
        self.chainRegistry = chainRegistry
        self.proxyOperationFactory = proxyOperationFactory
        self.operationQueue = operationQueue
        self.metaAccountsRepository = metaAccountsRepository
        self.workingQueue = workingQueue
        self.eventCenter = eventCenter
        changesCalculator = .init(chainModel: chainModel)
        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
        identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
    }

    override func performSyncUp() {
        let chainId = chainModel.chainId

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            completeImmediate(ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            completeImmediate(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        performSyncUp(
            connection: connection,
            runtimeProvider: runtimeProvider
        )
    }

    private func performSyncUp(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) {
        pendingCall.cancel()

        let proxyListWrapper = proxyOperationFactory.fetchProxyList(
            requestFactory: requestFactory,
            connection: connection,
            runtimeProvider: runtimeProvider
        )
        let metaAccountsOperation = metaAccountsRepository.fetchAllOperation(with: .init())

        let changesOperation = changesOperation(
            proxyListWrapper: proxyListWrapper,
            metaAccountsOperation: metaAccountsOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            identityOperationFactory: identityOperationFactory,
            chainModel: chainModel
        )

        let saveOperation = saveOperation(dependingOn: changesOperation)
        saveOperation.addDependency(changesOperation.targetOperation)

        let compoundWrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: changesOperation.allOperations
        )

        executeCancellable(
            wrapper: compoundWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: pendingCall,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case .success:
                self?.eventCenter.notify(with: AccountsChanged(method: .automatically))
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    private func changesOperation(
        proxyListWrapper: CompoundOperationWrapper<[ProxiedAccountId: [ProxyAccount]]>,
        metaAccountsOperation: BaseOperation<[ManagedMetaAccountModel]>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        chainModel: ChainModel
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let proxyListOperation = ClosureOperation<[ProxiedAccountId: [ProxyAccount]]> {
            let proxyList = try proxyListWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsOperation.extractNoCancellableResultData()

            // We only need remote proxieds of accounts whose proxies are in our database
            let proxies = proxyList.compactMapValues { accounts in
                accounts.filter {
                    chainMetaAccounts.has(accountId: $0.accountId, in: chainModel)
                }
            }.filter { !$0.value.isEmpty }
            return proxies
        }
        proxyListOperation.addDependency(proxyListWrapper.targetOperation)
        proxyListOperation.addDependency(metaAccountsOperation)

        let identityWrapper = identityOperationFactory.createIdentityWrapperByAccountId(
            for: {
                let proxieds = try proxyListOperation.extractNoCancellableResultData()
                return Array(proxieds.keys)
            },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chainModel.chainFormat
        )

        identityWrapper.addDependency(operations: [proxyListOperation])

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> { [changesCalculator] in
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsOperation.extractNoCancellableResultData()
            let remoteProxieds = try proxyListOperation.extractNoCancellableResultData()

            return try changesCalculator.calculateUpdates(
                from: remoteProxieds,
                chainMetaAccounts: chainMetaAccounts,
                identities: identities
            )
        }

        mapOperation.addDependency(identityWrapper.targetOperation)
        mapOperation.addDependency(metaAccountsOperation)
        mapOperation.addDependency(proxyListOperation)

        let dependencies = proxyListWrapper.allOperations + identityWrapper.allOperations +
            [proxyListOperation, metaAccountsOperation]

        return .init(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func saveOperation(
        dependingOn updatingMetaAccountsOperation: CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>>
    ) -> BaseOperation<Void> {
        metaAccountsRepository.saveOperation({
            let metaAccounts = try updatingMetaAccountsOperation.targetOperation.extractNoCancellableResultData()
            return metaAccounts.newOrUpdatedItems
        }, {
            let metaAccounts = try updatingMetaAccountsOperation.targetOperation.extractNoCancellableResultData()
            return metaAccounts.removedItems.map(\.identifier)
        })
    }

    override func stopSyncUp() {
        pendingCall.cancel()
    }
}
