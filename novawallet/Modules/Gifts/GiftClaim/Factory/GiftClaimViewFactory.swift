import Foundation
import Foundation_iOS
import BigInt

struct GiftClaimViewFactory {
    static func createView(
        info: ClaimableGiftInfo,
        totalAmount: BigUInt
    ) -> GiftClaimViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chain = chainRegistry.getChain(for: info.chainId),
            let chainAsset = chain.chainAssetForSymbol(info.assetSymbol),
            let currencyManager = CurrencyManager.shared
        else { return nil }

        let interactor = createInteractor(
            info: info,
            chain: chain,
            chainRegistry: chainRegistry,
            totalAmount: totalAmount
        )

        guard let interactor else { return nil }

        let wireframe = GiftClaimWireframe()

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let viewModelFactory = GiftClaimViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            assetIconViewModelFactory: AssetIconViewModelFactory()
        )

        let presenter = GiftClaimPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = GiftClaimViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

// MARK: - Private

private extension GiftClaimViewFactory {
    static func createInteractor(
        info: ClaimableGiftInfo,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        totalAmount: BigUInt
    ) -> GiftClaimInteractor? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        guard
            let selectedWallet = SelectedWalletSettings.shared.value,
            let selectedAccount = selectedWallet.fetch(for: chain.accountRequest()),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: info.chainId),
            let connection = chainRegistry.getConnection(for: info.chainId)
        else { return nil }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount, chain: chain)

        let claimDescriptionFactory = ClaimableGiftDescriptionFactory(
            chainRegistry: chainRegistry,
            transferCommandFactory: SubstrateTransferCommandFactory(),
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy()
        )

        let walletRepository = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createManagedMetaAccountRepository(for: nil, sortDescriptors: [])

        let walletOperationFactory = GiftClaimWalletOperationFactory(
            walletRepository: walletRepository
        )

        return GiftClaimInteractor(
            claimDescriptionFactory: claimDescriptionFactory,
            chainRegistry: chainRegistry,
            giftInfo: info,
            assetStorageInfoFactory: AssetStorageInfoOperationFactory(),
            walletOperationFactory: walletOperationFactory,
            logger: Logger.shared,
            operationQueue: operationQueue,
            totalAmount: totalAmount
        )
    }
}
