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
        guard
            let chainAsset = stakingState.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let chainAccount = metaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        guard let interactor = createInteractor(state: stakingState) else {
            return nil
        }

        let wireframe = StakingAmountWireframe(stakingState: stakingState)

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
            wireframe: wireframe,
            interactor: interactor,
            amount: amount,
            selectedAccount: chainAccount,
            assetInfo: assetInfo,
            rewardDestViewModelFactory: rewardDestViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let view = StakingAmountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter
        presenter.view = view
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        state: StakingSharedState
    ) -> StakingAmountInteractor? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()),
            let rewardCalculationService = state.rewardCalculationService else {
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
            chain: chainAsset.chain,
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
            rewardService: rewardCalculationService,
            operationManager: operationManager
        )

        return interactor
    }
}
