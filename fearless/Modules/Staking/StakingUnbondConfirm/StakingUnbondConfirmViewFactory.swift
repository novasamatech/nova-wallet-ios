import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

struct StakingUnbondConfirmViewFactory {
    static func createView(
        from amount: Decimal,
        state: StakingSharedState
    ) -> StakingUnbondConfirmViewProtocol? {
        guard let interactor = createInteractor(state: state) else {
            return nil
        }

        let wireframe = StakingUnbondConfirmWireframe()

        let presenter = createPresenter(
            from: interactor,
            wireframe: wireframe,
            amount: amount,
            chainAsset: state.settings.value
        )

        let view = StakingUnbondConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        from interactor: StakingUnbondConfirmInteractorInputProtocol,
        wireframe: StakingUnbondConfirmWireframeProtocol,
        amount: Decimal,
        chainAsset: ChainAsset
    ) -> StakingUnbondConfirmPresenter {
        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let confirmationViewModelFactory = StakingUnbondConfirmViewModelFactory(assetInfo: assetInfo)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        return StakingUnbondConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            inputAmount: amount,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            explorers: chainAsset.chain.explorers,
            logger: Logger.shared
        )
    }

    private static func createInteractor(state: StakingSharedState) -> StakingUnbondConfirmInteractor? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationManager = OperationManagerFacade.sharedManager

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            ) else {
            return nil
        }

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        return StakingUnbondConfirmInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicServiceFactory: extrinsicServiceFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy(),
            operationManager: operationManager
        )
    }
}
