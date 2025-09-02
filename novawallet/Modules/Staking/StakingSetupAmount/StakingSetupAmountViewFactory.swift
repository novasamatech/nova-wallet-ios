import Foundation
import Foundation_iOS
import Operation_iOS

struct StakingSetupAmountViewFactory {
    static func createView(
        for state: RelaychainStartStakingStateProtocol
    ) -> StakingSetupAmountViewProtocol? {
        let accountRequest = state.chainAsset.chain.accountRequest()

        guard
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: accountRequest),
            let interactor = createInteractor(for: state, selectedAccount: selectedAccount) else {
            return nil
        }

        let wireframe = StakingSetupAmountWireframe(state: state)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let viewModelFactory = StakingAmountViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(networkViewModelFactory: NetworkViewModelFactory())

        let dataValidatingFactory = RelaychainStakingValidatorFacade(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let balanceDerivationFactory = StakingTypeBalanceFactory(stakingType: state.stakingType)

        let presenter = StakingSetupAmountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            stakingTypeViewModelFactory: SelectedStakingViewModelFactory(),
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            balanceDerivationFactory: balanceDerivationFactory,
            dataValidatingFactory: dataValidatingFactory,
            accountId: selectedAccount.accountId,
            chainAsset: state.chainAsset,
            recommendsMultipleStakings: state.recommendsMultipleStakings,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let keyboardStrategy = EventDrivenKeyboardStrategy(events: [.viewDidAppear], triggersOnes: true)
        let view = StakingSetupAmountViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: keyboardStrategy,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: RelaychainStartStakingStateProtocol,
        selectedAccount: ChainAccountResponse
    ) -> StakingSetupAmountInteractor? {
        let chainId = state.chainAsset.chain.chainId

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount, chain: state.chainAsset.chain)

        let recommendationFactory = StakingRecommendationMediatorFactory(
            chainRegistry: chainRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let feeProxy = ExtrinsicFeeProxy()

        let extrinsicProxy = StartStakingExtrinsicProxy(
            selectedAccount: selectedAccount,
            runtimeService: runtimeProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return .init(
            state: state,
            selectedAccount: selectedAccount,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            extrinsicFeeProxy: feeProxy,
            extrinsicSubmissionProxy: extrinsicProxy,
            recommendationMediatorFactory: recommendationFactory,
            runtimeService: runtimeProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            currencyManager: currencyManager
        )
    }
}
