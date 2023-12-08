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
            identityOperationFactory: identityOperationFactory,
            chainModel: chainModel
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

    private static func metaAccountsUpdates(
        metaAccounts: [ManagedMetaAccountModel],
        accountId: ProxiedAccountId,
        proxies: [ProxyAccount],
        identities: [ProxiedAccountId: AccountIdentity],
        chainModel: ChainModel
    ) -> SyncChanges<ManagedMetaAccountModel> {
        let cryptoType = !chainModel.isEthereumBased ? MultiassetCryptoType.sr25519 : MultiassetCryptoType.ethereumEcdsa

        let remoteProxies = proxies.map {
            ProxyAccountModel(
                type: $0.type,
                accountId: $0.accountId,
                status: .new
            )
        }
        let localProxies = metaAccounts
            .filter { $0.info.type == .proxy && $0.info.has(accountId: accountId, chainId: chainModel.chainId) }
            .flatMap(\.info.chainAccounts)
            .compactMap(\.proxy)

        let diffCalculator = DataChangesDiffCalculator<ProxyAccountModel>()
        let difference = diffCalculator.diff(newItems: localProxies, oldItems: remoteProxies) { oldElement, newElement in
            oldElement.accountId == newElement.accountId &&
                oldElement.type == newElement.type &&
                (oldElement.status == .new || oldElement.status == .active)
        }

        let markAsDeletedItems = difference.removedItems.map {
            ProxyAccountModel(
                type: $0.type,
                accountId: $0.accountId,
                status: .revoked
            )
        }

        let updatedItems = difference.newOrUpdatedItems + markAsDeletedItems

        return updatedItems.reduce(into: SyncChanges<ManagedMetaAccountModel>()) { result, proxy in
            if let metaAccount = metaAccounts.first(where: { $0.info.type == .proxy && $0.info.has(accountId: accountId, chainId: chainModel.chainId) }) {
                let proxyWalletExists = metaAccounts.contains(where: { $0.info.has(accountId: proxy.accountId, chainId: chainModel.chainId) })
                guard proxyWalletExists else {
                    result.removedItems.append(metaAccount)
                    return
                }

                if var proxyChainAccount = metaAccount.info.proxyChainAccount(proxyAccountId: proxy.accountId, type: proxy.type) {
                    let chainAccountModel = ChainAccountModel(
                        chainId: proxyChainAccount.chainId,
                        accountId: proxyChainAccount.accountId,
                        publicKey: proxyChainAccount.publicKey,
                        cryptoType: proxyChainAccount.cryptoType,
                        proxy: proxy
                    )

                    result.newOrUpdatedItems.append(ManagedMetaAccountModel(
                        info: metaAccount.info.replacingChainAccount(chainAccountModel),
                        isSelected: metaAccount.isSelected,
                        order: metaAccount.order
                    ))
                    return
                } else {
                    result.removedItems.append(metaAccount)
                    return
                }
            }

            let chainAccountModel = ChainAccountModel(
                chainId: chainModel.chainId,
                accountId: accountId,
                publicKey: accountId,
                cryptoType: cryptoType.rawValue,
                proxy: proxy
            )

            let newWallet = ManagedMetaAccountModel(info: MetaAccountModel(
                metaId: UUID().uuidString,
                name: identities[accountId]?.displayName ?? accountId.toHexString(),
                substrateAccountId: accountId,
                substrateCryptoType: cryptoType.rawValue,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [chainAccountModel],
                type: .proxy
            ))

            result.newOrUpdatedItems.append(newWallet)
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
        let metaAccountsOperations = OperationCombiningService(operationManager: operationManager) {
            let proxyList = try proxyListWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsOperation.extractNoCancellableResultData()

            let proxies = proxyList.compactMapValues { accounts in
                accounts.filter { account in
                    chainMetaAccounts.contains {
                        $0.info.has(accountId: account.accountId, chainId: self.chainModel.chainId)
                    }
                }
            }.filter { !$0.value.isEmpty }

            let identityWrapper = identityOperationFactory.createIdentityWrapperByAccountId(
                for: { Array(proxies.keys) },
                engine: connection,
                runtimeService: runtimeProvider,
                chainFormat: chainModel.chainFormat
            )

            let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> {
                let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
                let changes = proxies.map {
                    Self.metaAccountsUpdates(
                        metaAccounts: chainMetaAccounts,
                        accountId: $0.key,
                        proxies: $0.value,
                        identities: identities,
                        chainModel: chainModel
                    )
                }

                return SyncChanges(
                    newOrUpdatedItems: changes.flatMap(\.newOrUpdatedItems),
                    removedItems: changes.flatMap(\.removedItems)
                )
            }

            mapOperation.addDependency(identityWrapper.targetOperation)

            let wrapper = CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: identityWrapper.allOperations
            )
            return [wrapper]
        }.longrunOperation()

        metaAccountsOperations.addDependency(proxyListWrapper.targetOperation)
        metaAccountsOperations.addDependency(metaAccountsOperation)

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> {
            let metaAccounts = try metaAccountsOperations.extractNoCancellableResultData().first ?? SyncChanges<ManagedMetaAccountModel>()

            return metaAccounts
        }
        mapOperation.addDependency(metaAccountsOperations)

        let dependencies = proxyListWrapper.allOperations + [metaAccountsOperation, metaAccountsOperations]

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
        clear(cancellable: &pendingCall)
    }
}
