import Foundation
import Operation_iOS

final class CrosschainAssetsExchangeProvider {
    private var xcmTransfers: XcmTransfers?
    private var allChains: [ChainModel.Id: ChainModel]?
    private let syncQueue: DispatchQueue

    let syncService: XcmTransfersSyncServiceProtocol
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol

    init(
        syncService: XcmTransfersSyncServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol
    ) {
        self.syncService = syncService
        self.chainRegistry = chainRegistry
        self.logger = logger

        syncQueue = DispatchQueue(label: "io.novawallet.crosschainassetsprovider.\(UUID().uuidString)")
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

    private func provideExchanges(
        notifingIn queue: DispatchQueue,
        onChange: @escaping ([AssetsExchangeProtocol]) -> Void
    ) {
        guard let xcmTransfers, let allChains else {
            return
        }

        let exchange = CrosschainAssetsExchange(allChains: allChains, transfers: xcmTransfers)

        dispatchInQueueWhenPossible(queue) {
            onChange([exchange])
        }
    }
}

extension CrosschainAssetsExchangeProvider: AssetsExchangeProviding {
    func provide(notifingIn queue: DispatchQueue, onChange: @escaping ([AssetsExchangeProtocol]) -> Void) {
        syncService.notificationCallback = { [weak self] transfersResult in
            switch transfersResult {
            case let .success(transfers):
                self?.xcmTransfers = transfers
                self?.provideExchanges(notifingIn: queue, onChange: onChange)
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

            provideExchanges(notifingIn: queue, onChange: onChange)
        }
    }
}

final class CrosschainAssetsExchange {
    let allChains: [ChainModel.Id: ChainModel]
    let transfers: XcmTransfers

    init(allChains: [ChainModel.Id: ChainModel], transfers: XcmTransfers) {
        self.allChains = allChains
        self.transfers = transfers
    }
}

extension CrosschainAssetsExchange: AssetsExchangeProtocol {
    func fetchAvailableDirections() -> CompoundOperationWrapper<AssetsExchange.Directions> {
        let operation = ClosureOperation {
            self.transfers.chains.reduce(into: AssetsExchange.Directions()) { accum, chain in
                for asset in chain.assets {
                    let destinations = Set(asset.xcmTransfers.map {
                        ChainAssetId(chainId: $0.destination.chainId, assetId: $0.destination.assetId)
                    })

                    accum[ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)] = destinations
                }
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createAvailableDirectionsWrapper(
        for chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<AssetsExchange.AvailableAssets> {
        let operation = ClosureOperation {
            let availableAssets = self.transfers.transfers(from: chainAssetId).map {
                ChainAssetId(
                    chainId: $0.destination.chainId,
                    assetId: $0.destination.assetId
                )
            }

            return Set(availableAssets)
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
