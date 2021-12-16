import SoraFoundation
import SoraKeystore
import RobinHood
import SubstrateSdk
import CommonWallet

struct StakingBondMoreViewFactory {
    static func createView(from state: StakingSharedState) -> StakingBondMoreViewProtocol? {
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let chainAsset = state.settings.value,
            let selectedAccount = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        guard let interactor = createInteractor(selectedAccount: selectedAccount, state: state) else {
            return nil
        }

        let wireframe = StakingBondMoreWireframe(state: state)

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            logger: Logger.shared
        )

        let viewController = StakingBondMoreViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = viewController
        interactor.presenter = presenter
        dataValidatingFactory.view = viewController

        return viewController
    }

    private static func createInteractor(
        selectedAccount: ChainAccountResponse,
        state: StakingSharedState
    ) -> StakingBondMoreInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let interactor = StakingBondMoreInteractor(
            selectedAccount: selectedAccount,
            chainAsset: state.settings.value,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            feeProxy: feeProxy,
            operationManager: operationManager
        )

        return interactor
    }
}
