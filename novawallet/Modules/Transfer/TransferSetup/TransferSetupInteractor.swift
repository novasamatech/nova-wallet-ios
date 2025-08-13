import Foundation
import Operation_iOS
import SubstrateSdk

final class TransferSetupInteractor: AccountFetching, AnyCancellableCleaning {
    weak var presenter: TransferSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let whoChainAssetPeer: TransferSetupPeer
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let chainsStore: ChainsStoreProtocol
    let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationManager: OperationManagerProtocol
    let web3NamesService: Web3NameServiceProtocol?

    private var xcmTransfers: XcmTransfers?
    private var peerChainAsset: ChainAsset?
    private var restrictedChainAssetPeers: [ChainAsset]?

    var destinationChainAsset: ChainAsset? {
        switch whoChainAssetPeer {
        case .origin:
            return chainAsset
        case .destination:
            return peerChainAsset
        }
    }

    init(
        chainAsset: ChainAsset,
        whoChainAssetPeer: TransferSetupPeer,
        restrictedChainAssetPeers: [ChainAsset]?,
        xcmTransfers: XcmTransfers?,
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        chainsStore: ChainsStoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        web3NamesService: Web3NameServiceProtocol?,
        operationManager: OperationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.whoChainAssetPeer = whoChainAssetPeer
        peerChainAsset = restrictedChainAssetPeers?.first
        self.restrictedChainAssetPeers = restrictedChainAssetPeers
        self.xcmTransfers = xcmTransfers
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

        chainsStore.setup(with: { $0.syncMode.enabled() })
    }

    private func provideAvailableTransfers() {
        guard let xcmTransfers = xcmTransfers else {
            presenter?.didReceiveAvailableXcm(peerChainAssets: [], xcmTransfers: nil)
            return
        }

        switch whoChainAssetPeer {
        case .origin:
            provideAvailableOrigins(for: xcmTransfers)
        case .destination:
            provideAvailableDestinations(for: xcmTransfers)
        }
    }

    private func provideAvailableDestinations(for xcmTransfers: XcmTransfers) {
        let transfers = xcmTransfers.getDestinations(for: chainAsset.chainAssetId)

        guard !transfers.isEmpty else {
            presenter?.didReceiveAvailableXcm(peerChainAssets: [], xcmTransfers: xcmTransfers)
            return
        }

        let destinations: [ChainAsset] = transfers.compactMap { destination in
            guard
                let chain = chainsStore.getChain(for: destination.chainId),
                let asset = chain.asset(for: destination.assetId)
            else {
                return nil
            }

            return ChainAsset(chain: chain, asset: asset)
        }

        providePeerChainAssets(for: destinations, xcmTransfers: xcmTransfers)
    }

    private func provideAvailableOrigins(for xcmTransfers: XcmTransfers) {
        let transfers = xcmTransfers.getOrigins(for: chainAsset.chainAssetId)

        guard !transfers.isEmpty else {
            presenter?.didReceiveAvailableXcm(peerChainAssets: [], xcmTransfers: xcmTransfers)
            return
        }

        let origins: [ChainAsset] = transfers.compactMap { chainAssetId in
            guard
                let chain = chainsStore.getChain(for: chainAssetId.chainId),
                let asset = chain.asset(for: chainAssetId.assetId)
            else {
                return nil
            }

            return ChainAsset(chain: chain, asset: asset)
        }

        providePeerChainAssets(for: origins, xcmTransfers: xcmTransfers)
    }

    private func providePeerChainAssets(for foundChainAssets: [ChainAsset], xcmTransfers: XcmTransfers) {
        guard let restrictedChainAssetPeers = restrictedChainAssetPeers else {
            presenter?.didReceiveAvailableXcm(peerChainAssets: foundChainAssets, xcmTransfers: xcmTransfers)
            return
        }

        let chainAssetIds = Set(foundChainAssets.map(\.chainAssetId))

        let availableChainAssets = restrictedChainAssetPeers.filter { chainAssetIds.contains($0.chainAssetId) }

        presenter?.didReceiveAvailableXcm(peerChainAssets: availableChainAssets, xcmTransfers: xcmTransfers)
    }

    private func fetchAccounts(for peerChain: ChainModel) {
        let chain: ChainModel

        switch whoChainAssetPeer {
        case .origin:
            chain = chainAsset.chain
        case .destination:
            chain = peerChain
        }

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
    func setup(peerChainAsset: ChainAsset) {
        setupChainsStore()
        setupXcmTransfersSyncService()
        fetchAccounts(for: peerChainAsset.chain)
        web3NamesService?.setup()
        self.peerChainAsset = peerChainAsset
    }

    func peerChainAssetDidChanged(_ chainAsset: ChainAsset) {
        fetchAccounts(for: chainAsset.chain)
        peerChainAsset = chainAsset
    }

    func search(web3Name: String) {
        guard let destinationChainAsset = destinationChainAsset else {
            return
        }

        guard let web3NamesService = web3NamesService else {
            let error = Web3NameServiceError.serviceNotFound(web3Name, destinationChainAsset.chain.name)
            presenter?.didReceive(error: error)
            return
        }

        web3NamesService.cancel()
        web3NamesService.search(
            name: web3Name,
            destinationChainAsset: destinationChainAsset
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case let .success(recipients):
                    self.presenter?.didReceive(recipients: recipients, for: web3Name)
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
