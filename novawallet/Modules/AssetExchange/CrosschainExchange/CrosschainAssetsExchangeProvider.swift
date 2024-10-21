import Foundation
import Operation_iOS

final class CrosschainAssetsExchangeProvider: AssetsExchangeBaseProvider {
    private var xcmTransfers: XcmTransfers?
    private var allChains: [ChainModel.Id: ChainModel]?

    let syncService: XcmTransfersSyncServiceProtocol
    let chainRegistry: ChainRegistryProtocol

    init(
        syncService: XcmTransfersSyncServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol
    ) {
        self.syncService = syncService
        self.chainRegistry = chainRegistry

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

        let exchange = CrosschainAssetsExchange(allChains: allChains, transfers: xcmTransfers)

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
