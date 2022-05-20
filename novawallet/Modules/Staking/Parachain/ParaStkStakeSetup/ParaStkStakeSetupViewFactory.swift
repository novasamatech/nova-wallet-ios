import Foundation
import SoraFoundation
import SubstrateSdk

struct ParaStkStakeSetupViewFactory {
    static func createView(with state: ParachainStakingSharedState) -> ParaStkStakeSetupViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(from: state) else {
            return nil
        }

        let wireframe = ParaStkStakeSetupWireframe(state: state)

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo
        )

        let dataValidationFactory = ParachainStaking.ValidatorFactory(
            presentable: wireframe,
            assetDisplayInfo: assetDisplayInfo
        )

        let localizationManager = LocalizationManager.shared
        let presenter = ParaStkStakeSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidationFactory,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkStakeSetupViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidationFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from state: ParachainStakingSharedState
    ) -> ParaStkStakeSetupInteractor? {
        guard
            let chainAsset = state.settings.value,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ),
            let collatorService = state.collatorService,
            let rewardService = state.rewardCalculationService
        else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            ),
            let connection = chainRegistry.getConnection(
                for: chainAsset.chain.chainId
            ) else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: selectedAccount.chainAccount.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: selectedAccount.chainAccount.cryptoType,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )

        let storageFacade = SubstrateDataStorageFacade.shared
        let repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)

        return ParaStkStakeSetupInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            collatorService: collatorService,
            rewardService: rewardService,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            repositoryFactory: repositoryFactory,
            identityOperationFactory: identityOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
