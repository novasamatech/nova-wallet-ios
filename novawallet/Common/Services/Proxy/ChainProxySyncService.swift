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
    private var pendingCall = CancellableCallStore()

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

        executeCancellable(
            wrapper: compoundWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: pendingCall,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success:
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    struct ProxidIdentifier: Hashable {
        let accountId: AccountId
        let proxyType: Proxy.ProxyType
    }

    struct ProxidValue {
        let proxy: ProxyAccountModel
        let metaAccount: ManagedMetaAccountModel
    }

    private static func metaAccountsUpdates(
        localProxies: [ProxidIdentifier: ProxidValue],
        accountId: ProxiedAccountId,
        proxies: [ProxyAccount],
        identities: [ProxiedAccountId: AccountIdentity],
        chainModel: ChainModel
    ) -> SyncChanges<ManagedMetaAccountModel> {
        let updatedProxiedMetaAccounts = proxies.reduce(into: [ManagedMetaAccountModel]()) { result, proxy in
            let key = ProxidIdentifier(accountId: accountId, proxyType: proxy.type)
            if let localProxy = localProxies[key] {
                if localProxy.proxy.status == .revoked {
                    let updatedItem = localProxy.metaAccount.replacingInfo(localProxy.metaAccount.info.replacingProxy(
                        chainId: chainModel.chainId,
                        proxy: localProxy.proxy.replacingStatus(.new)
                    ))
                    result.append(updatedItem)
                } else {
                    return
                }
            } else {
                let cryptoType = !chainModel.isEthereumBased ? MultiassetCryptoType.sr25519 : MultiassetCryptoType.ethereumEcdsa

                let chainAccountModel = ChainAccountModel(
                    chainId: chainModel.chainId,
                    accountId: accountId,
                    publicKey: accountId,
                    cryptoType: cryptoType.rawValue,
                    proxy: .init(type: proxy.type, accountId: proxy.accountId, status: .new)
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
                    type: .proxied
                ))

                result.append(newWallet)
            }
        }
        let revokedProxiedMetaAccounts = localProxies.filter { localProxy in
            !proxies.contains { $0.accountId == localProxy.key.accountId && $0.type == localProxy.key.proxyType }
        }.map { localProxy in
            let updatedItem = localProxy.value.metaAccount.replacingInfo(localProxy.value.metaAccount.info.replacingProxy(
                chainId: chainModel.chainId,
                proxy: localProxy.value.proxy.replacingStatus(.new)
            ))
            return updatedItem
        }

        return .init(newOrUpdatedItems: updatedProxiedMetaAccounts + revokedProxiedMetaAccounts)
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

            let proxies = proxyList.compactMapValues { accounts in
                accounts.filter { account in
                    chainMetaAccounts.contains {
                        $0.info.has(accountId: account.accountId, chainId: chainModel.chainId)
                    }
                }
            }.filter { !$0.value.isEmpty }
            return proxies
        }
        proxyListOperation.addDependency(proxyListWrapper.targetOperation)
        proxyListOperation.addDependency(metaAccountsOperation)

        let identityWrapper = identityOperationFactory.createIdentityWrapperByAccountId(
            for: {
                let proxies = try proxyListOperation.extractNoCancellableResultData()
                return Array(proxies.keys)
            },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chainModel.chainFormat
        )

        identityWrapper.addDependency(operations: [proxyListOperation])

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> {
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsOperation.extractNoCancellableResultData()
            let proxies = try proxyListOperation.extractNoCancellableResultData()
            let localProxieds = chainMetaAccounts.reduce(into: [ProxidIdentifier: ProxidValue]()) { result, item in
                if let chainAccount = item.info.proxyChainAccount(chainId: chainModel.chainId), let proxy = chainAccount.proxy {
                    result[.init(accountId: chainAccount.accountId, proxyType: proxy.type)] = .init(proxy: proxy, metaAccount: item)
                }
            }

            let changes = proxies.map {
                Self.metaAccountsUpdates(
                    localProxies: localProxieds,
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
        mapOperation.addDependency(metaAccountsOperation)
        mapOperation.addDependency(proxyListOperation)

        let dependencies = proxyListWrapper.allOperations + identityWrapper.allOperations + [proxyListOperation, metaAccountsOperation]

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
