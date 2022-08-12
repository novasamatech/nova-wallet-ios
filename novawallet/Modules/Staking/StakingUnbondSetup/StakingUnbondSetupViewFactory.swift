import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

struct StakingUnbondSetupViewFactory {
    static func createView(for state: StakingSharedState) -> StakingUnbondSetupViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(state: state),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = StakingUnbondSetupWireframe(state: state)

        let assetInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            logger: Logger.shared
        )

        let view = StakingUnbondSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        state: StakingSharedState
    ) -> StakingUnbondSetupInteractor? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared,
            let stakingDurationFactory = try? state.createStakingDurationOperationFactory(
                for: chainAsset.chain
            ) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationManager = OperationManagerFacade.sharedManager

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager,
            signingWrapperFactory: SigningWrapperFactory()
        )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        return StakingUnbondSetupInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stakingDurationOperationFactory: stakingDurationFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy(),
            operationManager: operationManager,
            currencyManager: currencyManager
        )
    }
}
