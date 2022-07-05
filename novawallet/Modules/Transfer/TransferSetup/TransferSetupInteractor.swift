import Foundation

final class TransferSetupInteractor {
    weak var presenter: TransferSetupInteractorOutputProtocol?

    let originChainAssetId: ChainAssetId
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let chainsStore: ChainsStoreProtocol

    private var xcmTransfers: XcmTransfers?

    init(
        originChainAssetId: ChainAssetId,
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        chainsStore: ChainsStoreProtocol
    ) {
        self.originChainAssetId = originChainAssetId
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.chainsStore = chainsStore
    }

    deinit {
        xcmTransfersSyncService.throttle()
    }

    private func setupXcmTransfersSyncService() {
        xcmTransfersSyncService.notificationCallback = { [weak self] result in
            switch result {
            case let .success(xcmTransfers):
                self?.xcmTransfers = xcmTransfers
                self?.provideAvailableTransfers()
            case let .failure(error):
                self?.presenter?.didReceive(error: error)
            }
        }

        xcmTransfersSyncService.setup()
    }

    private func setupChainsStore() {
        chainsStore.delegate = self

        chainsStore.setup()
    }

    private func provideAvailableTransfers() {
        guard let xcmTransfers = xcmTransfers else {
            presenter?.didReceiveAvailableXcm(destinations: [], xcmTransfers: nil)
            return
        }

        let transfers = xcmTransfers.transfers(from: originChainAssetId)

        guard !transfers.isEmpty else {
            presenter?.didReceiveAvailableXcm(destinations: [], xcmTransfers: xcmTransfers)
            return
        }

        let destinations: [ChainAsset] = transfers.compactMap { xcmTransfer in
            guard
                let chain = chainsStore.getChain(for: xcmTransfer.destination.chainId),
                let asset = chain.asset(for: xcmTransfer.destination.assetId)
            else {
                return nil
            }

            return ChainAsset(chain: chain, asset: asset)
        }

        presenter?.didReceiveAvailableXcm(destinations: destinations, xcmTransfers: xcmTransfers)
    }
}

extension TransferSetupInteractor: TransferSetupInteractorIntputProtocol {
    func setup() {
        setupChainsStore()
        setupXcmTransfersSyncService()
    }
}

extension TransferSetupInteractor: ChainsStoreDelegate {
    func didUpdateChainsStore(_: ChainsStoreProtocol) {
        provideAvailableTransfers()
    }
}
