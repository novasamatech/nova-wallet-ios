import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

struct StakingBondMoreConfirmViewFactory {
    static func createView(
        from amount: Decimal,
        state: StakingSharedState
    ) -> StakingBondMoreConfirmationViewProtocol? {
        guard let interactor = createInteractor(for: state) else {
            return nil
        }

        let wireframe = StakingBondMoreConfirmationWireframe(state: state)

        let presenter = createPresenter(
            from: interactor,
            wireframe: wireframe,
            amount: amount,
            assetInfo: state.settings.value.assetDisplayInfo
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
        assetInfo: AssetBalanceDisplayInfo
    ) -> StakingBondMoreConfirmationPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let confirmationViewModelFactory = StakingBondMoreConfirmViewModelFactory(
            assetInfo: assetInfo
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        return StakingBondMoreConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            inputAmount: amount,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        for state: StakingSharedState
    ) -> StakingBondMoreConfirmationInteractor? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let accountResponse = metaAccount.fetch(for: chainAsset.chain.accountRequest()) else {
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
            operationManager: OperationManagerFacade.sharedManager
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
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
