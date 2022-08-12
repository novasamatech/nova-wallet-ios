import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

struct StakingBondMoreConfirmViewFactory {
    static func createView(
        from amount: Decimal,
        state: StakingSharedState
    ) -> StakingBondMoreConfirmationViewProtocol? {
        guard let interactor = createInteractor(for: state),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = StakingBondMoreConfirmationWireframe(state: state)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let presenter = createPresenter(
            from: interactor,
            wireframe: wireframe,
            amount: amount,
            assetInfo: state.settings.value.assetDisplayInfo,
            chain: state.settings.value.chain,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let view = StakingBondMoreConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        from interactor: StakingBondMoreConfirmationInteractorInputProtocol,
        wireframe: StakingBondMoreConfirmationWireframeProtocol,
        amount: Decimal,
        assetInfo: AssetBalanceDisplayInfo,
        chain: ChainModel,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) -> StakingBondMoreConfirmationPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let confirmationViewModelFactory = StakingBondMoreConfirmViewModelFactory()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        return StakingBondMoreConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            inputAmount: amount,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            chain: chain,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        for state: StakingSharedState
    ) -> StakingBondMoreConfirmationInteractor? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let accountResponse = metaAccount.fetch(for: chainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager,
            signingWrapperFactory: SigningWrapperFactory()
        )

        let accountRepositoryFactory = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        return StakingBondMoreConfirmationInteractor(
            selectedAccount: accountResponse,
            chainAsset: chainAsset,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            feeProxy: ExtrinsicFeeProxy(),
            operationManager: OperationManagerFacade.sharedManager,
            currencyManager: currencyManager
        )
    }
}
