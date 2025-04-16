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
    let operationQueue: OperationQueue
    let operationManager: OperationManagerProtocol
    let web3NamesService: Web3NameServiceProtocol?
    let repositoryFactory: SubstrateRepositoryFactoryProtocol

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
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        chainsStore: ChainsStoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        web3NamesService: Web3NameServiceProtocol?,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        operationQueue: OperationQueue,
        operationManager: OperationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.whoChainAssetPeer = whoChainAssetPeer
        peerChainAsset = restrictedChainAssetPeers?.first
        self.restrictedChainAssetPeers = restrictedChainAssetPeers
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.chainsStore = chainsStore
        self.accountRepository = accountRepository
        self.web3NamesService = web3NamesService
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
        self.operationManager = operationManager
    }

    deinit {
        xcmTransfersSyncService.throttle()
    }
}

// MARK: Private

private extension TransferSetupInteractor {
    func setupXcmTransfersSyncService() {
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

    func setupChainsStore() {
        chainsStore.delegate = self

        chainsStore.setup(with: { $0.syncMode.enabled() })
    }

    func provideAvailableTransfers() {
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

    func provideAvailableDestinations(for xcmTransfers: XcmTransfers) {
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

    func provideAvailableOrigins(for xcmTransfers: XcmTransfers) {
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

    func providePeerChainAssets(for foundChainAssets: [ChainAsset], xcmTransfers: XcmTransfers) {
        guard let restrictedChainAssetPeers = restrictedChainAssetPeers else {
            presenter?.didReceiveAvailableXcm(peerChainAssets: foundChainAssets, xcmTransfers: xcmTransfers)
            return
        }

        let chainAssetIds = Set(foundChainAssets.map(\.chainAssetId))

        let availableChainAssets = restrictedChainAssetPeers.filter { chainAssetIds.contains($0.chainAssetId) }

        presenter?.didReceiveAvailableXcm(peerChainAssets: availableChainAssets, xcmTransfers: xcmTransfers)
    }

    func fetchAccounts(for peerChain: ChainModel) {
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

    func handleFetchAccountsResult(_ result: Result<[MetaAccountChainResponse], Error>) {
        switch result {
        case let .failure(error):
            presenter?.didReceive(error: error)
            presenter?.didReceive(metaChainAccountResponses: [])
        case let .success(accounts):
            let notWatchOnlyAccounts = accounts.filter { $0.metaAccount.type != .watchOnly }
            presenter?.didReceive(metaChainAccountResponses: notWatchOnlyAccounts)
        }
    }

    func createHighestAmountChainAssetWrapper(
        from chainAssets: [ChainAsset]
    ) -> CompoundOperationWrapper<ChainAsset?> {
        let chainAssetIds = chainAssets.map(\.chainAssetId)
        let repository = repositoryFactory.createAssetBalanceRepository(for: Set(chainAssetIds))

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let resultOperation = ClosureOperation<ChainAsset?> {
            let balances = try fetchOperation.extractNoCancellableResultData()
            let highestAmountBalance = balances
                .sorted { $0.transferable > $1.transferable }
                .first

            guard
                let highestAmountBalance,
                let chainAsset = chainAssets.first(where: { $0.chainAssetId == highestAmountBalance.chainAssetId })
            else { return nil }

            return chainAsset
        }

        resultOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [fetchOperation]
        )
    }
}

// MARK: TransferSetupInteractorIntputProtocol

extension TransferSetupInteractor: TransferSetupInteractorIntputProtocol {
    func setup(availablePeers: [ChainAsset]) {
        guard !availablePeers.isEmpty else {
            return
        }

        let setupClosure: (ChainAsset) -> Void = { [weak self] peerChainAsset in
            self?.presenter?.didReceive(peerChainAsset: peerChainAsset)
            self?.setupChainsStore()
            self?.setupXcmTransfersSyncService()
            self?.fetchAccounts(for: peerChainAsset.chain)
            self?.web3NamesService?.setup()
            self?.peerChainAsset = peerChainAsset
        }

        if availablePeers.count == 1 {
            setupClosure(availablePeers[0])
        } else {
            let wrapper = createHighestAmountChainAssetWrapper(from: availablePeers)

            execute(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                runningCallbackIn: .main
            ) { result in
                switch result {
                case let .success(chainAsset):
                    if let chainAsset {
                        setupClosure(chainAsset)
                    } else {
                        setupClosure(availablePeers[0])
                    }
                case let .failure(error):
                    setupClosure(availablePeers[0])
                }
            }
        }
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

// MARK: ChainsStoreDelegate

extension TransferSetupInteractor: ChainsStoreDelegate {
    func didUpdateChainsStore(_: ChainsStoreProtocol) {
        provideAvailableTransfers()
    }
}
