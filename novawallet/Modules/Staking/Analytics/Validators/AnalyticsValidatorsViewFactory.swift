import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import SubstrateSdk

struct AnalyticsValidatorsViewFactory {
    static func createView(for state: StakingSharedState) -> AnalyticsValidatorsViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(state: state) else {
            return nil
        }

        let wireframe = AnalyticsValidatorsWireframe(state: state)
        let presenter = createPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAssetInfo: chainAsset.chainAssetInfo
        )

        let view = AnalyticsValidatorsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        state: StakingSharedState
    ) -> AnalyticsValidatorsInteractor? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let chainAsset = state.settings.value,
            let selectedAddress = metaAccount.fetch(
                for: chainAsset.chain.accountRequest()
            )?.toAddress() else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connetion = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)

        let interactor = AnalyticsValidatorsInteractor(
            selectedAddress: selectedAddress,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            identityOperationFactory: identityOperationFactory,
            operationManager: operationManager,
            connection: connetion,
            runtimeService: runtimeService,
            storageRequestFactory: requestFactory,
            logger: logger
        )

        return interactor
    }

    private static func createPresenter(
        interactor: AnalyticsValidatorsInteractor,
        wireframe: AnalyticsValidatorsWireframe,
        chainAssetInfo: ChainAssetDisplayInfo
    ) -> AnalyticsValidatorsPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainAssetInfo.asset)

        let viewModelFactory = AnalyticsValidatorsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            chainAssetInfo: chainAssetInfo
        )

        let presenter = AnalyticsValidatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        return presenter
    }
}
