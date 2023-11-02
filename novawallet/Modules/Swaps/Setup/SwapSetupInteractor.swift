import UIKit
import RobinHood
import BigInt

final class SwapSetupInteractor: SwapBaseInteractor {
    let xcmTransfersSyncService: XcmTransfersSyncServiceProtocol
    let chainRegistry: ChainRegistryProtocol
    private var xcmTransfers: XcmTransfers?

    init(
        xcmTransfersSyncService: XcmTransfersSyncServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        assetConversionOperationFactory: AssetConversionOperationFactoryProtocol,
        assetConversionFeeService: AssetConversionFeeServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        selectedWallet: MetaAccountModel,
        operationQueue: OperationQueue
    ) {
        self.xcmTransfersSyncService = xcmTransfersSyncService
        self.chainRegistry = chainRegistry

        super.init(
            assetConversionOperationFactory: assetConversionOperationFactory,
            assetConversionFeeService: assetConversionFeeService,
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
                feeChainAsset?.chainAssetId
            ].compactMap { $0 }
        )
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
                self?.presenter?.didReceive(error: .xcm(error))
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

        payChainAsset.map {
            set(payChainAsset: $0)
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
