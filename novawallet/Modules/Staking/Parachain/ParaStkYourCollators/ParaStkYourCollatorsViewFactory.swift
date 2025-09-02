import Foundation
import Foundation_iOS
import SubstrateSdk

struct ParaStkYourCollatorsViewFactory {
    static func createView(for state: ParachainStakingSharedStateProtocol) -> CollatorStkYourCollatorsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
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
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
        let viewModelFactory = CollatorStkYourCollatorsViewModelFactory(
            balanceViewModeFactory: balanceViewModelFactory,
            assetPrecision: assetDisplayInfo.assetPrecision,
            chainFormat: chainAsset.chain.chainFormat
        )

        let presenter = ParaStkYourCollatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccount: selectedAccount,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        let view = CollatorStkYourCollatorsViewController(
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
        state: ParachainStakingSharedStateProtocol
    ) -> ParaStkYourCollatorsInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let collatorService = state.collatorService
        let rewardService = state.rewardCalculationService

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let collatorsOperationFactory = ParaStkCollatorsOperationFactory(
            requestFactory: requestFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            identityFactory: identityProxyFactory,
            chainFormat: chainAsset.chain.chainFormat
        )

        return ParaStkYourCollatorsInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            collatorService: collatorService,
            rewardService: rewardService,
            collatorsOperationFactory: collatorsOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
