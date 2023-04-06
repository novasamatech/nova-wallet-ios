import Foundation
import RobinHood
import SubstrateSdk

final class TransferSetupInteractor: AccountFetching, AnyCancellableCleaning {
    weak var presenter: TransferSetupInteractorOutputProtocol?

    let originChainAssetId: ChainAssetId
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let chainsStore: ChainsStoreProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol
    let web3NamesService: Web3NameServiceProtocol

    private var xcmTransfers: XcmTransfers?
    private var destinationChainAsset: ChainAsset?

    init(
        originChainAssetId: ChainAssetId,
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        chainsStore: ChainsStoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        web3NamesService: Web3NameServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.originChainAssetId = originChainAssetId
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.chainsStore = chainsStore
        self.accountRepository = accountRepository
        self.web3NamesService = web3NamesService
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
        fetchAllMetaAccountChainResponses(
            for: chain.accountRequest(),
            repository: accountRepository,
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
    func setup(destinationChainAsset: ChainAsset) {
        setupChainsStore()
        setupXcmTransfersSyncService()
        fetchAccounts(for: destinationChainAsset.chain)
        web3NamesService.setup()
        self.destinationChainAsset = destinationChainAsset
    }

    func destinationChainAssetDidChanged(_ chainAsset: ChainAsset) {
        fetchAccounts(for: chainAsset.chain)
        destinationChainAsset = chainAsset
    }

    func search(web3Name: String) {
        guard let destinationChainAsset = destinationChainAsset,
              let originAsset = chainsStore.getChainAsset(for: originChainAssetId)?.asset else {
            return
        }

        web3NamesService.cancel()
        web3NamesService.search(
            name: web3Name,
            chainAsset: destinationChainAsset,
            originAsset: originAsset
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case let .success(recipients):
                    self.presenter?.didReceive(kiltRecipients: recipients, for: web3Name)
                case let .failure(error):
                    self.presenter?.didReceive(error: error)
                }
            }
        }
    }
}

extension TransferSetupInteractor: ChainsStoreDelegate {
    func didUpdateChainsStore(_: ChainsStoreProtocol) {
        provideAvailableTransfers()
    }
}
