import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingRebondConfirmationViewFactory {
    static func createView(for variant: SelectedRebondVariant, state: StakingSharedState)
        -> StakingRebondConfirmationViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(state: state) else {
            return nil
        }

        let wireframe = StakingRebondConfirmationWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = createPresenter(
            for: variant,
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: chainAsset.assetDisplayInfo
        )

        let view = StakingRebondConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createPresenter(
        for variant: SelectedRebondVariant,
        interactor: StakingRebondConfirmationInteractorInputProtocol,
        wireframe: StakingRebondConfirmationWireframeProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        assetInfo: AssetBalanceDisplayInfo
    ) -> StakingRebondConfirmationPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let confirmationViewModelFactory = StakingRebondConfirmationViewModelFactory(assetInfo: assetInfo)

        return StakingRebondConfirmationPresenter(
            variant: variant,
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
    ) -> StakingRebondConfirmationInteractor? {
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

        return StakingRebondConfirmationInteractor(
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
