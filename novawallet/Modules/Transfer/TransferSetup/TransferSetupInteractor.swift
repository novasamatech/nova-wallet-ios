import Foundation
import RobinHood

final class TransferSetupInteractor: AccountFetching {
    weak var presenter: TransferSetupInteractorOutputProtocol?

    let originChainAssetId: ChainAssetId
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let chainsStore: ChainsStoreProtocol
    let accountsRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol

    private var xcmTransfers: XcmTransfers?

    init(
        originChainAssetId: ChainAssetId,
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        chainsStore: ChainsStoreProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.originChainAssetId = originChainAssetId
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.chainsStore = chainsStore
        accountsRepository = accountRepositoryFactory.createMetaAccountRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )
        self.operationManager = operationManager
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

    private func fetchAccounts(for chain: ChainModel) {
        let request = ChainAccountRequest(
            chainId: chain.chainId,
            addressPrefix: chain.addressPrefix,
            isEthereumBased: chain.isEthereumBased
        )
        fetchAllMetaAccountChainResponses(
            for: request,
            repository: accountsRepository,
            operationManager: operationManager
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleFetchAccountsResult(result)
            }
        }
    }

    private func handleFetchAccountsResult(_ result: Result<[MetaAccountChainResponse], Error>) {
        switch result {
        case let .failure(error):
            presenter?.didReceive(error: error)
            presenter?.didReceive(metaChainAccountResponses: [])
        case let .success(accounts):
            let notWatchOnlyAccounts = accounts.filter { $0.metaAccount.type != .watchOnly }
            presenter?.didReceive(metaChainAccountResponses: notWatchOnlyAccounts)
        }
    }
}

extension TransferSetupInteractor: TransferSetupInteractorIntputProtocol {
    func setup() {
        setupChainsStore()
        setupXcmTransfersSyncService()
    }

    func destinationChainDidChanged(_ chain: ChainModel) {
        fetchAccounts(for: chain)
    }
}

extension TransferSetupInteractor: ChainsStoreDelegate {
    func didUpdateChainsStore(_: ChainsStoreProtocol) {
        provideAvailableTransfers()
    }
}
