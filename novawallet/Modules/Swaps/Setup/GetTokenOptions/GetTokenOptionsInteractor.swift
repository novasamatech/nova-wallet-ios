import Foundation

final class GetTokenOptionsInteractor {
    weak var presenter: GetTokenOptionsInteractorOutputProtocol?

    let selectedWallet: MetaAccountModel
    let assetModelObservable: AssetListModelObservable
    let destinationChainAsset: ChainAsset
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let rampProvider: RampProviderProtocol
    let logger: LoggerProtocol

    private var xcmTransfers: XcmTransfers?

    init(
        selectedWallet: MetaAccountModel,
        destinationChainAsset: ChainAsset,
        assetModelObservable: AssetListModelObservable,
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        rampProvider: RampProviderProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.destinationChainAsset = destinationChainAsset
        self.assetModelObservable = assetModelObservable
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.rampProvider = rampProvider
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
        let purchaseActions = rampProvider.buildOnRampActions(
            for: destinationChainAsset,
            accountId: selectedAccount.chainAccount.accountId
        )

        let receiveAvailable = TokenOperation.checkReceiveOperationAvailable(
            walletType: selectedWallet.type,
            chainAsset: destinationChainAsset
        ).available

        let buyAvailable = TokenOperation.checkBuyOperationAvailable(
            rampActions: purchaseActions,
            walletType: selectedWallet.type,
            chainAsset: destinationChainAsset
        ).available

        let model = GetTokenOptionsModel(
            availableXcmOrigins: availableXcmOrigins,
            xcmTransfers: xcmTransfers,
            receiveAccount: receiveAvailable ? selectedAccount : nil,
            buyOptions: buyAvailable ? purchaseActions : []
        )

        presenter?.didReceive(model: model)
    }

    private func determineAvailableXcmOrigins() -> [ChainAsset] {
        guard let xcmTransfers = xcmTransfers else {
            return []
        }

        let balances = assetModelObservable.state.value.balances
        let chains = assetModelObservable.state.value.allChains

        let availableOrigins = xcmTransfers
            .transferChainAssets(to: destinationChainAsset.chainAssetId)
            .compactMap { chainAssetId in
                if
                    case let .success(balance) = balances[chainAssetId],
                    balance.transferable > 0,
                    let chain = chains[chainAssetId.chainId],
                    let asset = chain.asset(for: chainAssetId.assetId) {
                    return (ChainAsset(chain: chain, asset: asset), balance.transferable)
                } else {
                    return nil
                }
            }
            .sorted { balance1, balance2 in
                balance1.1 > balance2.1
            }
            .map(\.0)

        return availableOrigins
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
