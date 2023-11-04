import UIKit
import RobinHood
import BigInt

final class SwapSetupInteractor: SwapBaseInteractor {
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol

    private var xcmTransfers: XcmTransfers?
    private var canPayFeeInAssetCall = CancellableCallStore()

    init(
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        assetConversionAggregatorFactory: AssetConversionAggregationFactoryProtocol,
        assetConversionFeeService: AssetConversionFeeServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        assetStorageFactory: AssetStorageInfoOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue
    ) {
        self.xcmTransfersSyncService = xcmTransfersSyncService

        super.init(
            assetConversionAggregator: assetConversionAggregatorFactory,
            assetConversionFeeService: assetConversionFeeService,
            chainRegistry: chainRegistry,
            assetStorageFactory: assetStorageFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            currencyManager: currencyManager,
            selectedWallet: selectedWallet,
            operationQueue: operationQueue
        )
    }

    weak var presenter: SwapSetupInteractorOutputProtocol? {
        basePresenter as? SwapSetupInteractorOutputProtocol
    }

    private var receiveChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions(activeChainAssets: activeChainAssets)
        }
    }

    private var payChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions(activeChainAssets: activeChainAssets)
        }
    }

    private var feeChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions(activeChainAssets: activeChainAssets)
        }
    }

    private var activeChainAssets: Set<ChainAssetId> {
        Set(
            [
                receiveChainAsset?.chainAssetId,
                payChainAsset?.chainAssetId,
                feeChainAsset?.chainAssetId,
                feeChainAsset?.chain.utilityChainAssetId()
            ].compactMap { $0 }
        )
    }

    deinit {
        xcmTransfersSyncService.throttle()
        canPayFeeInAssetCall.cancel()
    }

    private func setupXcmTransfersSyncService() {
        xcmTransfersSyncService.notificationCallback = { [weak self] result in
            switch result {
            case let .success(xcmTransfers):
                self?.xcmTransfers = xcmTransfers
                self?.provideAvailableTransfers()
            case let .failure(error):
                self?.presenter?.didReceive(setupError: .xcm(error))
            }
        }

        xcmTransfersSyncService.setup()
    }

    private func provideAvailableTransfers() {
        guard let xcmTransfers = xcmTransfers, let payChainAsset = payChainAsset else {
            presenter?.didReceiveAvailableXcm(origins: [], xcmTransfers: nil)
            return
        }

        let chainAssets = xcmTransfers.transferChainAssets(to: payChainAsset.chainAssetId)

        guard !chainAssets.isEmpty else {
            presenter?.didReceiveAvailableXcm(origins: [], xcmTransfers: xcmTransfers)
            return
        }

        let origins: [ChainAsset] = chainAssets.compactMap { chainAsset in
            guard
                chainAsset != payChainAsset.chainAssetId,
                let chain = chainRegistry.getChain(for: chainAsset.chainId),
                let asset = chain.asset(for: chainAsset.assetId)
            else {
                return nil
            }

            return ChainAsset(chain: chain, asset: asset)
        }

        presenter?.didReceiveAvailableXcm(origins: origins, xcmTransfers: xcmTransfers)
    }

    private func provideCanPayFee(for asset: ChainAsset) {
        canPayFeeInAssetCall.cancel()

        guard let utilityAssetId = asset.chain.utilityChainAssetId() else {
            presenter?.didReceiveCanPayFeeInPayAsset(false, chainAssetId: asset.chainAssetId)
            return
        }

        let wrapper = assetConversionAggregator.createAvailableDirectionsWrapper(for: asset)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: canPayFeeInAssetCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chainAssetIds):
                let canPayFee = chainAssetIds.contains(utilityAssetId)
                self?.presenter?.didReceiveCanPayFeeInPayAsset(canPayFee, chainAssetId: asset.chainAssetId)
            case let .failure(error):
                self?.presenter?.didReceive(setupError: .payAssetSetFailed(error))
            }
        }
    }

    override func setup() {
        super.setup()
        setupXcmTransfersSyncService()
    }
}

extension SwapSetupInteractor: SwapSetupInteractorInputProtocol {
    func setupXcm() {
        setupXcmTransfersSyncService()
    }

    func update(receiveChainAsset: ChainAsset?) {
        self.receiveChainAsset = receiveChainAsset
        receiveChainAsset.map {
            set(receiveChainAsset: $0)
        }
    }

    func update(payChainAsset: ChainAsset?) {
        self.payChainAsset = payChainAsset

        if let payChainAsset = payChainAsset {
            set(payChainAsset: payChainAsset)
            provideCanPayFee(for: payChainAsset)
        }

        provideAvailableTransfers()
    }

    func update(feeChainAsset: ChainAsset?) {
        self.feeChainAsset = feeChainAsset
        feeChainAsset.map {
            set(feeChainAsset: $0)
        }
    }
}
