import Foundation

final class GetTokenOptionsInteractor {
    weak var presenter: GetTokenOptionsInteractorOutputProtocol?

    let selectedWallet: MetaAccountModel
    let assetModelObservable: AssetListModelObservable
    let destinationChainAsset: ChainAsset
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let purchaseProvider: PurchaseProviderProtocol
    let logger: LoggerProtocol

    private var xcmTransfers: XcmTransfers?

    init(
        selectedWallet: MetaAccountModel,
        destinationChainAsset: ChainAsset,
        assetModelObservable: AssetListModelObservable,
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        purchaseProvider: PurchaseProviderProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.destinationChainAsset = destinationChainAsset
        self.assetModelObservable = assetModelObservable
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.purchaseProvider = purchaseProvider
        self.logger = logger
    }

    deinit {
        xcmTransfersSyncService.throttle()
    }

    private func provideModel() {
        let accountRequest = destinationChainAsset.chain.accountRequest()

        guard let selectedAccount = selectedWallet.fetchMetaChainAccount(for: accountRequest) else {
            presenter?.didReceive(model: .empty)
            return
        }

        let availableXcmOrigins = determineAvailableXcmOrigins()
        let purchaseActions = purchaseProvider.buildPurchaseActions(
            for: destinationChainAsset,
            accountId: selectedAccount.chainAccount.accountId
        )

        let receiveAvailable = TokenOperation.checkReceiveOperationAvailable(
            walletType: selectedWallet.type,
            chainAsset: destinationChainAsset
        ).available

        let buyAvailable = TokenOperation.checkBuyOperationAvailable(
            purchaseActions: purchaseActions,
            walletType: selectedWallet.type,
            chainAsset: destinationChainAsset
        ).available

        let model = GetTokenOptionsModel(
            availableXcmOrigins: availableXcmOrigins,
            receiveAccount: receiveAvailable ? selectedAccount : nil,
            buyOptions: buyAvailable ? purchaseActions : []
        )

        presenter?.didReceive(model: model)
    }

    private func determineAvailableXcmOrigins() -> Set<ChainAssetId> {
        guard let xcmTransfers = xcmTransfers else {
            return []
        }

        let balances = assetModelObservable.state.value.balances

        let availableOrigins = xcmTransfers
            .transferChainAssets(to: destinationChainAsset.chainAssetId)
            .filter { chainAssetId in
                if case let .success(balance) = balances[chainAssetId], balance.transferable > 0 {
                    return true
                } else {
                    return false
                }
            }

        return Set(availableOrigins)
    }

    private func setupBalances() {
        assetModelObservable.addObserver(with: self, queue: .main) { [weak self] _, _ in
            self?.provideModel()
        }
    }

    private func setupXcms() {
        xcmTransfersSyncService.notificationCallback = { [weak self] result in
            switch result {
            case let .success(xcmTransfers):
                self?.xcmTransfers = xcmTransfers
                self?.provideModel()
            case let .failure(error):
                self?.logger.error("Xcm sync failed: \(error)")
            }
        }

        xcmTransfersSyncService.setup()
    }
}

extension GetTokenOptionsInteractor: GetTokenOptionsInteractorInputProtocol {
    func setup() {
        setupBalances()
        setupXcms()

        provideModel()
    }
}
