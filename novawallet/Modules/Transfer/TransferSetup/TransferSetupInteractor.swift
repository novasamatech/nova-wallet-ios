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
    let web3NamesOperationFactory: Web3NamesOperationFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let kiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepositoryProtocol
    let slip44CoinsProvider: AnySingleValueProvider<Slip44CoinList>

    private var xcmTransfers: XcmTransfers?
    private var kiltRecipientsCancellableCall: CancellableCall?
    private var slip44CoinList: Slip44CoinList = []
    private var destinationChainAsset: ChainAsset?

    init(
        originChainAssetId: ChainAssetId,
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        chainsStore: ChainsStoreProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        web3NamesOperationFactory: Web3NamesOperationFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        kiltTransferAssetRecipientRepository: KiltTransferAssetRecipientRepositoryProtocol,
        slip44CoinsProvider: AnySingleValueProvider<Slip44CoinList>,
        operationManager: OperationManagerProtocol
    ) {
        self.originChainAssetId = originChainAssetId
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.chainsStore = chainsStore
        self.accountRepository = accountRepository
        self.web3NamesOperationFactory = web3NamesOperationFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.kiltTransferAssetRecipientRepository = kiltTransferAssetRecipientRepository
        self.slip44CoinsProvider = slip44CoinsProvider
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

    private func subscribeSlip44CoinList() {
        slip44CoinsProvider.removeObserver(self)

        let updateClosure: ([DataProviderChange<Slip44CoinList>]) -> Void = { [weak self] changes in
            if let result = changes.reduceToLastChange() {
                self?.slip44CoinList = result
            } else {
                self?.slip44CoinList = []
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter?.didReceive(error: error)
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        slip44CoinsProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
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

    private func provideKiltRecipient(_ name: String) {
        clear(cancellable: &kiltRecipientsCancellableCall)
        let web3NamesWrapper = web3NamesOperationFactory.searchWeb3NameWrapper(
            name: name,
            service: KnownServices.transferAssetRecipient,
            connection: connection,
            runtimeService: runtimeService
        )
        let chainName = destinationChainAsset?.chain.name ?? ""
        let wrapper: CompoundOperationWrapper<TransferAssetRecipientResponse?> =
            OperationCombiningService.compoundWrapper(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return nil
                }

                guard let web3Name = try web3NamesWrapper.targetOperation.extractNoCancellableResultData() else {
                    throw TransferSetupWeb3NameSearchError.accountNotFound(name)
                }
                guard let serviceURL = web3Name.serviceURLs.first else {
                    throw TransferSetupWeb3NameSearchError.serviceNotFound(name, chainName)
                }
                guard !self.slip44CoinList.isEmpty else {
                    throw TransferSetupWeb3NameSearchError.slip44ListIsEmpty
                }

                return self.kiltTransferAssetRecipientRepository.fetchRecipients(url: serviceURL)
            }

        wrapper.addDependency(wrapper: web3NamesWrapper)

        wrapper.targetOperation.completionBlock = { [weak self] in
            guard wrapper === self?.kiltRecipientsCancellableCall else {
                return
            }
            self?.kiltRecipientsCancellableCall = nil
            DispatchQueue.main.async {
                do {
                    let searchResult = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.handleSearchWeb3Name(response: searchResult, name: name)
                } catch let error as TransferSetupWeb3NameSearchError {
                    self?.presenter?.didReceive(error: error)
                } catch {
                    self?.presenter?.didReceive(error: TransferSetupWeb3NameSearchError.kiltService(error))
                }
            }
        }

        kiltRecipientsCancellableCall = wrapper

        operationManager.enqueue(
            operations: web3NamesWrapper.allOperations + wrapper.allOperations,
            in: .transient
        )
    }

    private func handleSearchWeb3Name(response: TransferAssetRecipientResponse?, name: String) {
        let chainName = destinationChainAsset?.chain.name ?? ""

        guard
            let response = response,
            let chainAsset = destinationChainAsset,
            let coin = slip44CoinList.first(where: {
                $0.symbol == chainAsset.asset.symbol
            }),
            let slip44Code = Int(coin.index)
        else {
            presenter?.didReceive(error: TransferSetupWeb3NameSearchError.serviceNotFound(name, chainName))
            return
        }

        guard let recipients = response.first(where: {
            guard let genesisHash = $0.key.chainId.genesisHash else {
                return false
            }
            return chainAsset.chain.chainId.hasPrefix(genesisHash) && slip44Code == $0.key.slip44Code
        })?.value else {
            presenter?.didReceive(error: TransferSetupWeb3NameSearchError.serviceNotFound(name, chainName))
            return
        }

        presenter?.didReceive(kiltRecipients: recipients, for: name)
    }
}

extension TransferSetupInteractor: TransferSetupInteractorIntputProtocol {
    func setup(destinationChainAsset: ChainAsset) {
        setupChainsStore()
        setupXcmTransfersSyncService()
        fetchAccounts(for: destinationChainAsset.chain)
        subscribeSlip44CoinList()
        self.destinationChainAsset = destinationChainAsset
    }

    func destinationChainAssetDidChanged(_ chainAsset: ChainAsset) {
        fetchAccounts(for: chainAsset.chain)
        destinationChainAsset = chainAsset
    }

    func search(web3Name: String) {
        provideKiltRecipient(web3Name)
    }
}

extension TransferSetupInteractor: ChainsStoreDelegate {
    func didUpdateChainsStore(_: ChainsStoreProtocol) {
        provideAvailableTransfers()
    }
}
