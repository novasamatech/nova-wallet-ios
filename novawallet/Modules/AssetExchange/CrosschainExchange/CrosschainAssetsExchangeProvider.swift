import Foundation
import Operation_iOS

final class CrosschainAssetsExchangeProvider: AssetsExchangeBaseProvider {
    private var xcmTransfers: XcmTransfers?
    private var allChains: [ChainModel.Id: ChainModel]?

    let wallet: MetaAccountModel
    let syncService: XcmTransfersSyncServiceProtocol
    let userStorageFacade: StorageFacadeProtocol
    let substrateStorageFacade: StorageFacadeProtocol
    let chainRegistry: ChainRegistryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let operationQueue: OperationQueue

    init(
        wallet: MetaAccountModel,
        syncService: XcmTransfersSyncServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.syncService = syncService
        self.chainRegistry = chainRegistry
        self.signingWrapperFactory = signingWrapperFactory
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
        self.operationQueue = operationQueue

        super.init(
            syncQueue: DispatchQueue(label: "io.novawallet.crosschainassetsprovider.\(UUID().uuidString)"),
            logger: logger
        )
    }

    private func handleChains(changes: [DataProviderChange<ChainModel>]) -> Bool {
        let updatedChains = changes.reduce(into: allChains ?? [:]) { accum, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                accum[newItem.chainId] = newItem
            case let .delete(deletedIdentifier):
                accum[deletedIdentifier] = nil
            }
        }

        guard allChains != updatedChains else {
            return false
        }

        allChains = updatedChains

        return true
    }

    private func updateStateIfNeeded() {
        guard let xcmTransfers, let allChains else {
            return
        }

        let host = CrosschainExchangeHost(
            wallet: wallet,
            allChains: allChains,
            chainRegistry: chainRegistry,
            signingWrapperFactory: signingWrapperFactory,
            xcmService: XcmTransferService(
                wallet: wallet,
                chainRegistry: chainRegistry,
                metadataHashOperationFactory: MetadataHashOperationFactory(
                    metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: substrateStorageFacade),
                    operationQueue: operationQueue
                ),
                userStorageFacade: userStorageFacade,
                substrateStorageFacade: substrateStorageFacade,
                operationQueue: operationQueue
            ),
            resolutionFactory: XcmTransferResolutionFactory(
                chainRegistry: chainRegistry,
                paraIdOperationFactory: ParaIdOperationFactory(
                    chainRegistry: chainRegistry,
                    operationQueue: operationQueue
                )
            ),
            xcmTransfers: xcmTransfers,
            operationQueue: operationQueue
        )

        let exchange = CrosschainAssetsExchange(host: host)

        updateState(with: [exchange])
    }

    // MARK: Subsclass

    override func performSetup() {
        syncService.notificationCallback = { [weak self] transfersResult in
            switch transfersResult {
            case let .success(transfers):
                self?.xcmTransfers = transfers
                self?.updateStateIfNeeded()
            case let .failure(error):
                self?.logger.error("Xcm trasfers fetch failed \(error)")
            }
        }

        syncService.notificationQueue = syncQueue

        syncService.setup()

        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: syncQueue,
            filterStrategy: .enabledChains
        ) { [weak self] changes in
            guard let self, handleChains(changes: changes) else {
                return
            }

            updateStateIfNeeded()
        }
    }

    override func performThrottle() {
        syncService.throttle()
        chainRegistry.chainsUnsubscribe(self)
    }
}
