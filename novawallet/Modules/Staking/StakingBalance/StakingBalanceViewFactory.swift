import SoraFoundation
import SoraKeystore
import RobinHood
import SubstrateSdk

struct StakingBalanceViewFactory {
    static func createView(for state: StakingSharedState) -> StakingBalanceViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let selectedWallet = SelectedWalletSettings.shared.value,
            let accountResponse = selectedWallet.fetch(for: chainAsset.chain.accountRequest()),
            let accountAddress = accountResponse.toAddress() else {
            return nil
        }

        guard let interactor = createInteractor(
            selectedAccount: accountResponse,
            state: state
        ) else { return nil }

        let wireframe = StakingBalanceWireframe(state: state)

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let viewModelFactory = StakingBalanceViewModelFactory(
            assetInfo: assetInfo,
            balanceViewModelFactory: balanceViewModelFactory,
            timeFormatter: TotalTimeFormatter()
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            accountAddress: accountAddress,
            countdownTimer: CountdownTimer()
        )

        interactor.presenter = presenter

        let viewController = StakingBalanceViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = viewController
        dataValidatingFactory.view = viewController

        return viewController
    }

    private static func createInteractor(
        selectedAccount: ChainAccountResponse,
        state: StakingSharedState
    ) -> StakingBalanceInteractor? {
        let operationManager = OperationManagerFacade.sharedManager

        let repositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        let interactor = StakingBalanceInteractor(
            chainAsset: state.settings.value,
            selectedAccount: selectedAccount,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            accountRepositoryFactory: repositoryFactory,
            operationManager: operationManager
        )

        return interactor
    }
}
