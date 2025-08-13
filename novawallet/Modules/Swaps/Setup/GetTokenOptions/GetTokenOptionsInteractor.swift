import Foundation

final class GetTokenOptionsInteractor {
    weak var presenter: GetTokenOptionsInteractorOutputProtocol?

    let selectedWallet: MetaAccountModel
    let assetModelObservable: AssetListModelObservable
    let destinationChainAsset: ChainAsset
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let featureChecker: FeatureSupportCheckerProtocol
    let rampProvider: RampProviderProtocol
    let rampType: RampActionType = .onRamp
    let logger: LoggerProtocol

    private var xcmTransfers: XcmTransfers?

    init(
        selectedWallet: MetaAccountModel,
        destinationChainAsset: ChainAsset,
        assetModelObservable: AssetListModelObservable,
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        featureChecker: FeatureSupportCheckerProtocol,
        rampProvider: RampProviderProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.destinationChainAsset = destinationChainAsset
        self.assetModelObservable = assetModelObservable
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.featureChecker = featureChecker
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
        let onRampActions = rampProvider.buildRampActions(
            for: destinationChainAsset,
            accountId: selectedAccount.chainAccount.accountId
        ).filter { $0.type == rampType }

        let receiveAvailable = TokenOperation.checkReceiveOperationAvailable(
            walletType: selectedWallet.type,
            chainAsset: destinationChainAsset
        ).available

        featureChecker.checkRampSupport(
            wallet: selectedWallet,
            rampActions: onRampActions,
            rampType: rampType,
            chainAsset: destinationChainAsset
        ) { [weak self] result in
            guard let self else {
                return
            }

            let buyAvailable = result.isAvailable

            let model = GetTokenOptionsModel(
                availableXcmOrigins: availableXcmOrigins,
                xcmTransfers: xcmTransfers,
                receiveAccount: receiveAvailable ? selectedAccount : nil,
                buyOptions: buyAvailable ? onRampActions : []
            )

            presenter?.didReceive(model: model)
        }
    }

    private func determineAvailableXcmOrigins() -> [ChainAsset] {
        guard let xcmTransfers = xcmTransfers else {
            return []
        }

        let balances = assetModelObservable.state.value.balances
        let chains = assetModelObservable.state.value.allChains

        let availableOrigins = xcmTransfers
            .getOrigins(for: destinationChainAsset.chainAssetId)
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
