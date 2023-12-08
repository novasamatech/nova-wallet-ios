import SubstrateSdk
import RobinHood
import BigInt

final class ChainProxySyncService: ObservableSyncService, AnyCancellableCleaning {
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let proxyOperationFactory: ProxyOperationFactoryProtocol
    let chainModel: ChainModel

    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)
    private var pendingCall: CancellableCall?

    init(
        chainModel: ChainModel,
        metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        chainRegistry: ChainRegistryProtocol,
        proxyOperationFactory: ProxyOperationFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue
    ) {
        self.chainModel = chainModel
        self.chainRegistry = chainRegistry
        self.proxyOperationFactory = proxyOperationFactory
        self.operationQueue = operationQueue
        self.metaAccountsRepository = metaAccountsRepository
        self.workingQueue = workingQueue
    }

    override func performSyncUp() {
        clear(cancellable: &pendingCall)

        guard chainModel.hasProxy else {
            completeImmediate(nil)
            return
        }

        let chainId = chainModel.chainId
        guard let connection = chainRegistry.getConnection(for: chainId),
              let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            completeImmediate(nil)
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
        let storageKeyFactory = StorageKeyFactory()
        let requestFactory = StorageRequestFactory(
            remoteFactory: storageKeyFactory,
            operationManager: operationManager
        )
        let proxyListWrapper = proxyOperationFactory.fetchProxyList(
            requestFactory: requestFactory,
            connection: connection,
            runtimeProvider: runtimeProvider
        )
        let metaAccountsOperation = metaAccountsRepository.fetchAllOperation(with: .init())
        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)

        let changesOperation = changesOperation(
            proxyListWrapper: proxyListWrapper,
            metaAccountsOperation: metaAccountsOperation,
            connection: connection,
            runtimeProvider: runtimeProvider,
            identityOperationFactory: identityOperationFactory
        )
        let saveOperation = saveOperation(dependingOn: changesOperation)
        saveOperation.addDependency(changesOperation.targetOperation)

        let compoundWrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: changesOperation.allOperations
        )

        saveOperation.completionBlock = { [weak self] in
            guard let workingQueue = self?.workingQueue, let mutex = self?.mutex else {
                return
            }

            dispatchInConcurrent(queue: workingQueue, locking: mutex) {
                guard self?.pendingCall === compoundWrapper else {
                    return
                }

                self?.pendingCall = nil

                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                    self?.completeImmediate(nil)
                } catch {
                    self?.completeImmediate(error)
                }
            }
        }

        pendingCall = compoundWrapper
        operationQueue.addOperations(compoundWrapper.allOperations, waitUntilFinished: false)
    }

    private func updatedMetaAccounts(
        metaAccounts: [ManagedMetaAccountModel],
        for accountId: AccountId,
        proxieds: [ProxiedAccount],
        identities: [AccountId: AccountIdentity]
    ) -> [ManagedMetaAccountModel] {
        guard metaAccounts.contains(where: { $0.info.has(accountId: accountId, chainId: chainModel.chainId) }) else {
            return []
        }
        let remoteProxieds = proxieds.map {
            ProxiedAccountModel(
                type: $0.type,
                accountId: $0.accountId,
                status: .new
            )
        }
        let localProxieds = metaAccounts
            .filter { $0.info.type == .proxy && $0.info.has(accountId: accountId, chainId: chainModel.chainId) }
            .flatMap(\.info.chainAccounts)
            .compactMap(\.proxied)

        let difference = localProxieds.diff(from: remoteProxieds) { oldElement, newElement in
            oldElement.accountId == newElement.accountId &&
                oldElement.type == newElement.type &&
                (oldElement.status == .new || oldElement.status == .active)
        }

        let markAsDeletedItems = difference.removedItems.map {
            ProxiedAccountModel(
                type: $0.type,
                accountId: $0.accountId,
                status: .revoked
            )
        }
        let newOrUpdatedItems = difference.newOrUpdatedItems + markAsDeletedItems

        return newOrUpdatedItems.map { item in
            let chainAccountModel = ChainAccountModel(
                chainId: chainModel.chainId,
                accountId: accountId,
                publicKey: Data(),
                cryptoType: MultiassetCryptoType.sr25519.rawValue,
                proxied: item
            )
            if let metaAccount = metaAccounts.first(where: {
                $0.info.has(accountId: accountId, chainId: chainModel.chainId) &&
                    $0.info.has(proxiedAccountId: item.accountId, type: item.type)
            }) {
                return ManagedMetaAccountModel(
                    info: metaAccount.info.replacingChainAccount(chainAccountModel),
                    isSelected: metaAccount.isSelected,
                    order: metaAccount.order
                )
            } else {
                return .init(info: MetaAccountModel(
                    metaId: UUID().uuidString,
                    name: identities[item.accountId]?.displayName ?? item.accountId.toHexString(),
                    substrateAccountId: accountId,
                    substrateCryptoType: MultiassetCryptoType.sr25519.rawValue,
                    substratePublicKey: nil,
                    ethereumAddress: nil,
                    ethereumPublicKey: nil,
                    chainAccounts: [chainAccountModel],
                    type: .proxy
                ))
            }
        }
    }

    private func changesOperation(
        proxyListWrapper: CompoundOperationWrapper<[AccountId: [ProxiedAccount]]>,
        metaAccountsOperation: BaseOperation<[ManagedMetaAccountModel]>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) -> CompoundOperationWrapper<[ManagedMetaAccountModel]> {
        let metaAccountsOperations = OperationCombiningService(operationManager: operationManager) {
            let proxyList = try proxyListWrapper.targetOperation.extractNoCancellableResultData()
            let proxiedsAccounts = Array(Set(proxyList.values.flatMap { $0 }.map(\.accountId)))
            let identityWrapper = identityOperationFactory.createIdentityWrapperByAccountId(
                for: { proxiedsAccounts },
                engine: connection,
                runtimeService: runtimeProvider,
                chainFormat: self.chainModel.chainFormat
            )

            let mapOperation = ClosureOperation<[ManagedMetaAccountModel]> {
                let chainMetaAccounts = try metaAccountsOperation.extractNoCancellableResultData()
                let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
                let metaAccounts = proxyList.compactMap {
                    self.updatedMetaAccounts(
                        metaAccounts: chainMetaAccounts,
                        for: $0.key,
                        proxieds: $0.value,
                        identities: identities
                    )
                }.flatMap { $0 } ?? []

                return metaAccounts
            }

            mapOperation.addDependency(metaAccountsOperation)
            mapOperation.addDependency(identityWrapper.targetOperation)

            let wrapper = CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [metaAccountsOperation] + identityWrapper.allOperations
            )
            return [wrapper]
        }.longrunOperation()

        metaAccountsOperations.addDependency(proxyListWrapper.targetOperation)

        let mapOperation = ClosureOperation<[ManagedMetaAccountModel]> {
            let metaAccounts = try metaAccountsOperations.extractNoCancellableResultData().first ?? []

            return metaAccounts
        }
        mapOperation.addDependency(metaAccountsOperations)

        let dependencies = proxyListWrapper.allOperations + [metaAccountsOperations]

        return .init(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func saveOperation(
        dependingOn updatingMetaAccountsOperation: CompoundOperationWrapper<[ManagedMetaAccountModel]>
    ) -> BaseOperation<Void> {
        metaAccountsRepository.saveOperation({
            let metaAccounts = try updatingMetaAccountsOperation.targetOperation.extractNoCancellableResultData()
            return metaAccounts
        }, { [] })
    }

    override func stopSyncUp() {
        clear(cancellable: &pendingCall)
    }
}
