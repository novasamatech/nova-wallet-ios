import Foundation
import Operation_iOS

final class GetTokenOptionsInteractor {
    weak var presenter: GetTokenOptionsInteractorOutputProtocol?

    let selectedWallet: MetaAccountModel
    let assetModelObservable: AssetListModelObservable
    let destinationChainAsset: ChainAsset
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let featureChecker: FeatureSupportCheckerProtocol
    let rampProvider: RampProviderProtocol
    let rampType: RampActionType = .onRamp
    let globalConfigProvider: GlobalConfigProviding
    let swapState: SwapTokensFlowStateProtocol?
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var xcmTransfers: XcmTransfers?
    private var changeNowUrl: URL?
    private var hasSwapRoute = false
    private var assetExchangeService: AssetsExchangeServiceProtocol?
    private let globalConfigCallStore = CancellableCallStore()
    private let swapRouteCallStore = CancellableCallStore()

    init(
        selectedWallet: MetaAccountModel,
        destinationChainAsset: ChainAsset,
        assetModelObservable: AssetListModelObservable,
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        featureChecker: FeatureSupportCheckerProtocol,
        rampProvider: RampProviderProtocol,
        globalConfigProvider: GlobalConfigProviding,
        swapState: SwapTokensFlowStateProtocol?,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.selectedWallet = selectedWallet
        self.destinationChainAsset = destinationChainAsset
        self.assetModelObservable = assetModelObservable
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.featureChecker = featureChecker
        self.rampProvider = rampProvider
        self.globalConfigProvider = globalConfigProvider
        self.swapState = swapState
        self.operationQueue = operationQueue
        self.logger = logger
    }

    var allOperations: [GetTokenOperation] {
        let swapOperations: [GetTokenOperation] = swapState != nil ? [.swap] : []
        let operations: [GetTokenOperation] = swapOperations + [.crosschain, .receive, .buy]

        return isNativeTao ? operations + [.changeNow] : operations
    }

    deinit {
        xcmTransfersSyncService.throttle()
        globalConfigCallStore.cancel()
        swapRouteCallStore.cancel()
    }

    private var isNativeTao: Bool {
        destinationChainAsset.chain.chainId == KnowChainId.bittensor && destinationChainAsset.isUtilityAsset
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
                buyOptions: buyAvailable ? onRampActions : [],
                changeNowUrl: changeNowUrl,
                swapState: hasSwapRoute ? swapState : nil
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

    private func setupSwapRoute() {
        guard let swapState else {
            return
        }

        let service = swapState.setupAssetExchangeService()
        assetExchangeService = service

        service.subscribeUpdates(for: self, notifyingIn: .main) { [weak self] in
            self?.fetchSwapRoute()
        }
    }

    private func fetchSwapRoute() {
        guard let assetExchangeService else {
            return
        }

        executeCancellable(
            wrapper: assetExchangeService.fetchAssetsOutWrapper(given: nil),
            inOperationQueue: operationQueue,
            backingCallIn: swapRouteCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(receivableAssets):
                hasSwapRoute = receivableAssets.contains(destinationChainAsset.chainAssetId)
                provideModel()
            case let .failure(error):
                logger.error("Swap routes fetch failed: \(error)")
            }
        }
    }

    private func setupChangeNowUrl() {
        guard isNativeTao else {
            return
        }

        executeCancellable(
            wrapper: globalConfigProvider.createConfigWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: globalConfigCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(config):
                self?.changeNowUrl = config.changeNowTaoUrl
                self?.provideModel()
            case let .failure(error):
                self?.logger.error("Global config fetch failed: \(error)")
            }
        }
    }
}

extension GetTokenOptionsInteractor: GetTokenOptionsInteractorInputProtocol {
    func setup() {
        setupBalances()
        setupXcms()
        setupChangeNowUrl()
        setupSwapRoute()

        provideModel()
    }
}
