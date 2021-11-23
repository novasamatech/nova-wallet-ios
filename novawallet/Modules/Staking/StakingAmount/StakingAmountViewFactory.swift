import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation
import SubstrateSdk

final class StakingAmountViewFactory {
    static func createView(
        with amount: Decimal?,
        stakingState: StakingSharedState
    ) -> StakingAmountViewProtocol? {
        guard let chainAsset = stakingState.settings.value else {
            return nil
        }

        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)
        let wireframe = StakingAmountWireframe(stakingState: stakingState)

        guard let presenter = createPresenter(
            view: view,
            wireframe: wireframe,
            amount: amount,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        guard let interactor = createInteractor(state: stakingState) else {
            return nil
        }

        view.uiFactory = UIFactory()
        view.localizationManager = LocalizationManager.shared

        presenter.interactor = interactor
        interactor.presenter = presenter
        view.presenter = presenter

        return view
    }

    private static func createPresenter(
        view: StakingAmountViewProtocol,
        wireframe: StakingAmountWireframeProtocol,
        amount: Decimal?,
        chainAsset: ChainAsset
    ) -> StakingAmountPresenter? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let accountItem = try? metaAccount.fetch(
                for: chainAsset.chain.accountRequest()
            )?.toAccountItem() else {
            return nil
        }

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = StakingAmountPresenter(
            amount: amount,
            selectedAccount: accountItem,
            assetInfo: assetInfo,
            rewardDestViewModelFactory: rewardDestViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe
        dataValidatingFactory.view = view

        return presenter
    }

    private static func createInteractor(
        state: StakingSharedState
    ) -> StakingAmountInteractor? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let facade = UserDataStorageFacade.shared

        let accountRepository = AccountRepositoryFactory(storageFacade: facade).createMetaAccountRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder]
        )

        let extrinsicService = ExtrinsicService(
            accountId: selectedAccount.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let interactor = StakingAmountInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            repository: accountRepository,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            rewardService: state.rewardCalculationService,
            operationManager: operationManager
        )

        return interactor
    }
}
