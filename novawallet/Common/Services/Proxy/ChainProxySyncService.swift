import SubstrateSdk
import RobinHood
import BigInt

final class ChainProxySyncService: ObservableSyncService, AnyCancellableCleaning {
    let metaAccountsRepository: AnyDataProviderRepository<MetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let proxyOperationFactory: ProxyOperationFactoryProtocol
    let chainModel: ChainModel

    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private lazy var operationManager = OperationManager(operationQueue: operationQueue)
    private var pendingCall: CancellableCall?

    init(
        chainModel: ChainModel,
        metaAccountsRepository: AnyDataProviderRepository<MetaAccountModel>,
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
        let changesOperation = changesOperation(
            proxyListWrapper: proxyListWrapper,
            metaAccountsOperation: metaAccountsOperation
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

    private func proxyMetaAccount(
        metaAccounts: [MetaAccountModel],
        for accountId: AccountId,
        proxieds: [ProxiedAccount]
    ) -> MetaAccountModel? {
        guard metaAccounts.contains(where: { $0.has(accountId: accountId, chainId: chainModel.chainId) }) else {
            return nil
        }
        let remoteProxieds = proxieds.map {
            ProxiedAccountModel(
                type: $0.type,
                accountId: $0.accountId,
                status: .new
            )
        }
        let substrateCryptoType = MultiassetCryptoType.sr25519.rawValue
        if let metaAccount = metaAccounts.first { $0.type == .proxy },
           let chainAccountModel = metaAccount.chainAccounts.first { $0.chainId == chainModel.chainId && $0.accountId == accountId } {
            let localProxieds: [ProxiedAccountModel] = Array(chainAccountModel.proxieds ?? [])
            let difference = localProxieds.diff(from: remoteProxieds) { oldElement, newElement in
                oldElement.accountId == newElement.accountId &&
                    oldElement.type == newElement.type &&
                    (oldElement.status == .new || oldElement.status == .active)
            }

            let newProxied = difference.newOrUpdatedItems + difference.removedItems.map {
                ProxiedAccountModel(
                    type: $0.type,
                    accountId: $0.accountId,
                    status: .revoked
                )
            }
            let chainAccountModel = ChainAccountModel(
                chainId: chainModel.chainId,
                accountId: accountId,
                publicKey: Data(),
                cryptoType: substrateCryptoType,
                proxieds: Set(newProxied)
            )
            return metaAccount.replacingChainAccount(chainAccountModel)
        } else {
            let chainAccountModel = ChainAccountModel(
                chainId: chainModel.chainId,
                accountId: accountId,
                publicKey: Data(),
                cryptoType: substrateCryptoType,
                proxieds: Set(remoteProxieds)
            )

            let metaAccount = MetaAccountModel(
                metaId: UUID().uuidString,
                name: "",
                substrateAccountId: accountId,
                substrateCryptoType: substrateCryptoType,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [chainAccountModel],
                type: .proxy
            )
            return metaAccount
        }
    }

    private func changesOperation(
        proxyListWrapper: CompoundOperationWrapper<[AccountId: [ProxiedAccount]]>,
        metaAccountsOperation: BaseOperation<[MetaAccountModel]>
    ) -> CompoundOperationWrapper<[MetaAccountModel]> {
        let updatingMetaAccountsOperation = ClosureOperation<[MetaAccountModel]> {
            let proxyList = try proxyListWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsOperation.extractNoCancellableResultData()
            let metaAccounts = proxyList.compactMap {
                self.proxyMetaAccount(
                    metaAccounts: chainMetaAccounts,
                    for: $0.key,
                    proxieds: $0.value
                )
            }

            return metaAccounts
        }

        updatingMetaAccountsOperation.addDependency(proxyListWrapper.targetOperation)
        updatingMetaAccountsOperation.addDependency(metaAccountsOperation)

        return CompoundOperationWrapper(
            targetOperation: updatingMetaAccountsOperation,
            dependencies: proxyListWrapper.allOperations + [metaAccountsOperation]
        )
    }

    private func saveOperation(
        dependingOn updatingMetaAccountsOperation: CompoundOperationWrapper<[MetaAccountModel]>
    ) -> BaseOperation<Void> {
        metaAccountsRepository.saveOperation({
            let newOrUpdatedMetaAccounts = try updatingMetaAccountsOperation.targetOperation.extractNoCancellableResultData()
            return newOrUpdatedMetaAccounts
        }, { [] })
    }

    override func stopSyncUp() {
        clear(cancellable: &pendingCall)
    }
}
