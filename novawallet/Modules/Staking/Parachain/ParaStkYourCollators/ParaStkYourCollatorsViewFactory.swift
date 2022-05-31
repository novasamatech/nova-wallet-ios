import Foundation
import SoraFoundation
import SubstrateSdk

struct ParaStkYourCollatorsViewFactory {
    static func createView(for state: ParachainStakingSharedState) -> ParaStkYourCollatorsViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        guard
            let interactor = createInteractor(
                for: chainAsset,
                selectedAccount: selectedAccount,
                state: state
            ) else {
            return nil
        }

        let wireframe = ParaStkYourCollatorsWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo)
        let viewModelFactory = ParaStkYourCollatorsViewModelFactory(
            balanceViewModeFactory: balanceViewModelFactory,
            assetPrecision: assetDisplayInfo.assetPrecision,
            chainFormat: chainAsset.chain.chainFormat
        )

        let presenter = ParaStkYourCollatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccount: selectedAccount,
            viewModelFactory: viewModelFactory
        )

        let view = ParaStkYourCollatorsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        state: ParachainStakingSharedState
    ) -> ParaStkYourCollatorsInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let collatorService = state.collatorService,
            let rewardService = state.rewardCalculationService else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let collatorsOperationFactory = ParaStkCollatorsOperationFactory(
            requestFactory: requestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: requestFactory)
        )

        return ParaStkYourCollatorsInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            collatorService: collatorService,
            rewardService: rewardService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            collatorsOperationFactory: collatorsOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
