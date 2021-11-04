import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import SubstrateSdk

final class StakingRedeemViewFactory {
    static func createView(for state: StakingSharedState) -> StakingRedeemViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(state: state) else {
            return nil
        }

        let wireframe = StakingRedeemWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = createPresenter(
            from: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: chainAsset.assetDisplayInfo
        )

        let view = StakingRedeemViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createPresenter(
        from interactor: StakingRedeemInteractorInputProtocol,
        wireframe: StakingRedeemWireframeProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo
    ) -> StakingRedeemPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let confirmationViewModelFactory = StakingRedeemViewModelFactory(assetInfo: assetInfo)

        return StakingRedeemPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        state: StakingSharedState
    ) -> StakingRedeemInteractor? {
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

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        return StakingRedeemInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            slashesOperationFactory: SlashesOperationFactory(storageRequestFactory: storageRequestFactory),
            feeProxy: feeProxy,
            operationManager: operationManager
        )
    }
}
