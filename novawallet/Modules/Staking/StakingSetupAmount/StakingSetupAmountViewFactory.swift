import Foundation
import SoraFoundation
import RobinHood

struct StakingSetupAmountViewFactory {
    static func createView(
        for state: RelaychainStartStakingStateProtocol
    ) -> StakingSetupAmountViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(for: state) else {
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

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let poolValidatingFactory = NominationPoolDataValidatorFactory(
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
            poolValidatingFactory: poolValidatingFactory,
            chainAsset: state.chainAsset,
            recommendsMultipleStakings: state.recommendsMultipleStakings,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = StakingSetupAmountViewController(
            presenter: presenter,
            keyboardAppearanceStrategy: EventDrivenKeyboardStrategy(
                events: [.viewDidAppear],
                triggersOnes: true
            ),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view
        poolValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: RelaychainStartStakingStateProtocol
    ) -> StakingSetupAmountInteractor? {
        let request = state.chainAsset.chain.accountRequest()
        let chainId = state.chainAsset.chain.chainId

        guard let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: request) else {
            return nil
        }

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
            operationManager: OperationManagerFacade.sharedManager
        ).createService(account: selectedAccount, chain: state.chainAsset.chain)

        let recommendationFactory = StakingRecommendationMediatorFactory(
            chainRegistry: chainRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
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
