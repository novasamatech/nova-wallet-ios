import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class StakingRebondSetupViewFactory {
    static func createView(for state: StakingSharedState) -> StakingRebondSetupViewProtocol? {
        // MARK: Interactor

        guard let interactor = createInteractor(state: state) else {
            return nil
        }

        // MARK: - Router

        let wireframe = StakingRebondSetupWireframe(state: state)

        // MARK: - Presenter

        let assetInfo = state.settings.value.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRebondSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo
        )

        // MARK: - View

        let localizationManager = LocalizationManager.shared

        let view = StakingRebondSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )
        view.localizationManager = localizationManager

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        state: StakingSharedState
    ) -> StakingRebondSetupInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let selectedAccount = SelectedWalletSettings.shared.value.fetch(
                for: chainAsset.chain.accountRequest()
            ),
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

        return StakingRebondSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            feeProxy: feeProxy,
            operationManager: operationManager
        )
    }
}
