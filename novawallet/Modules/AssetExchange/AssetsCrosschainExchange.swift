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
    let allChains: IndexedChainModels
    let transfers: XcmTransfers

    init(allChains: IndexedChainModels, transfers: XcmTransfers) {
        self.allChains = allChains
        self.transfers = transfers
    }

    private func createExchange(from origin: ChainAssetId, destination: ChainAssetId) -> CrosschainExchangeEdge? {
        .init(origin: origin, destination: destination)
    }
}

extension CrosschainAssetsExchange: AssetsExchangeProtocol {
    func availableDirectSwapConnections() -> CompoundOperationWrapper<[any AssetExchangableGraphEdge]> {
        let operation = ClosureOperation<[any AssetExchangableGraphEdge]> {
            self.transfers.chains.flatMap { xcmChain in
                xcmChain.assets.flatMap { xcmAsset in
                    let origin = ChainAssetId(chainId: xcmChain.chainId, assetId: xcmAsset.assetId)

                    return xcmAsset.xcmTransfers.compactMap { xcmTransfer in
                        let destination = ChainAssetId(
                            chainId: xcmTransfer.destination.chainId,
                            assetId: xcmTransfer.destination.assetId
                        )

                        return self.createExchange(from: origin, destination: destination)
                    }
                }
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
