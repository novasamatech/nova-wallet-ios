import Foundation
import SubstrateSdk
import SoraFoundation
import RobinHood

struct ParaStkYieldBoostSetupViewFactory {
    static func createView(
        with state: ParachainStakingSharedState,
        initData: ParaStkYieldBoostInitState
    ) -> ParaStkYieldBoostSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(with: state, currencyManager: currencyManager),
            let chainAsset = state.settings.value else {
            return nil
        }

        let wireframe = ParaStkYieldBoostSetupWireframe(state: state)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let accountDetailsViewModelFactory = ParaStkAccountDetailsViewModelFactory(chainAsset: chainAsset)

        let dataValidatingFactory = ParaStkYieldBoostValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )

        let presenter = ParaStkYieldBoostSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            initState: initData,
            balanceViewModelFactory: balanceViewModelFactory,
            accountDetailsViewModelFactory: accountDetailsViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: chainAsset,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = ParaStkYieldBoostSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    // swiftlint:disable:next function_body_length
    private static func createInteractor(
        with state: ParachainStakingSharedState,
        currencyManager: CurrencyManagerProtocol
    ) -> ParaStkYieldBoostSetupInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = state.settings.value,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetch(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let rewardService = state.rewardCalculationService else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        ).createService(account: selectedAccount, chain: chainAsset.chain)

        let yieldBoostOperationFactory = ParaStkYieldBoostOperationFactory()

        let childScheduleInterator = ParaStkYieldBoostScheduleInteractor(
            selectedAccount: selectedAccount,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            requestFactory: requestFactory,
            yeildBoostOperationFactory: yieldBoostOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let childCancelInteractor = ParaStkYieldBoostCancelInteractor(
            selectedAccount: selectedAccount,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy()
        )

        let interactor = ParaStkYieldBoostSetupInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            childScheduleInteractor: childScheduleInterator,
            childCancelInteractor: childCancelInteractor,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            rewardService: rewardService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            identityOperationFactory: identityOperationFactory,
            yieldBoostProviderFactory: ParaStkYieldBoostProviderFactory.shared,
            yieldBoostOperationFactory: yieldBoostOperationFactory,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        childScheduleInterator.presenter = interactor
        childCancelInteractor.presenter = interactor

        return interactor
    }
}
