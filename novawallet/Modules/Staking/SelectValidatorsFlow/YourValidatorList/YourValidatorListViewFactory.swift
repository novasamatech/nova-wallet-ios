import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore
import SubstrateSdk

struct YourValidatorListViewFactory {
    static func createView(for state: StakingSharedState) -> YourValidatorListViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(state: state) else {
            return nil
        }

        let wireframe = YourValidatorListWireframe(state: state)

        let chainInfo = chainAsset.chainAssetInfo

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainInfo.asset)

        let viewModelFactory = YourValidatorListViewModelFactory(
            balanceViewModeFactory: balanceViewModelFactory
        )

        let presenter = YourValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainInfo: chainInfo,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = YourValidatorListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(state: StakingSharedState) -> YourValidatorListInteractor? {
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

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let validatorOperationFactory = ValidatorOperationFactory(
            chainInfo: chainAsset.chainAssetInfo,
            eraValidatorService: state.eraValidatorService,
            rewardService: state.rewardCalculationService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        return YourValidatorListInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            eraValidatorService: state.eraValidatorService,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: operationManager
        )
    }
}
