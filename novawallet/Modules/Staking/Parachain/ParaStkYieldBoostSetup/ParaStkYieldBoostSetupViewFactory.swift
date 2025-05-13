import Foundation
import SubstrateSdk
import Foundation_iOS
import Operation_iOS

struct ParaStkYieldBoostSetupViewFactory {
    static func createView(
        with state: ParachainStakingSharedStateProtocol,
        initData: ParaStkYieldBoostInitState
    ) -> ParaStkYieldBoostSetupViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(with: state, currencyManager: currencyManager) else {
            return nil
        }

        let wireframe = ParaStkYieldBoostSetupWireframe(state: state)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let accountDetailsViewModelFactory = CollatorStakingAccountViewModelFactory(chainAsset: chainAsset)
        let yieldBoostCollatorViewModelFactory = YieldBoostCollatorSelectionFactory(
            chainFormat: chainAsset.chain.chainFormat
        )

        let dataValidatingFactory = ParaStkYieldBoostValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )

        let presenter = ParaStkYieldBoostSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            initState: initData,
            balanceViewModelFactory: balanceViewModelFactory,
            collatorSelectionViewModelFactory: yieldBoostCollatorViewModelFactory,
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
        with state: ParachainStakingSharedStateProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> ParaStkYieldBoostSetupInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = SelectedWalletSettings.shared.value?.fetch(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let rewardService = state.rewardCalculationService

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
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
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            identityProxyFactory: identityProxyFactory,
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
