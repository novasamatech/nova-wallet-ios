import Foundation
import Foundation_iOS
import Operation_iOS

struct GovernanceDelegateSetupViewFactory {
    static func createAddDelegationView(
        for state: GovernanceSharedState,
        delegateId: AccountId,
        delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>
    ) -> GovernanceDelegateSetupViewProtocol? {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.delegationsAddTitle()
        }

        return createModule(
            for: state,
            delegateId: delegateId,
            delegateDisplayInfo: delegateDisplayInfo,
            title: title,
            flowType: .add
        )
    }

    static func createEditDelegationView(
        for state: GovernanceSharedState,
        delegateId: AccountId,
        delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>
    ) -> GovernanceDelegateSetupViewProtocol? {
        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.govEditDelegation()
        }

        return createModule(
            for: state,
            delegateId: delegateId,
            delegateDisplayInfo: delegateDisplayInfo,
            title: title,
            flowType: .edit
        )
    }

    private static func createModule(
        for state: GovernanceSharedState,
        delegateId: AccountId,
        delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>,
        title: LocalizableResource<String>,
        flowType: GovernanceDelegationFlowType
    ) -> GovernanceDelegateSetupViewProtocol? {
        guard let interactor = createInteractor(for: state), let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        guard let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: chain.accountRequest()) else {
            return nil
        }

        guard let assetInfo = chain.utilityAssetDisplayInfo(), let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = GovernanceDelegateSetupWireframe(
            state: state,
            delegateDisplayInfo: delegateDisplayInfo,
            flowType: flowType
        )

        let votingLockId = state.governanceId(for: option)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let networkViewModelFactory = NetworkViewModelFactory()
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(networkViewModelFactory: networkViewModelFactory)

        let lockChangeViewModelFactory = ReferendumLockChangeViewModelFactory(
            assetDisplayInfo: assetInfo,
            votingLockId: votingLockId
        )

        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()

        let localizationManager = LocalizationManager.shared

        let dataValidatingFactory = GovernanceValidatorFactory.createFromPresentable(wireframe, govType: option.type)

        let presenter = GovernanceDelegateSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccountId: selectedAccount.accountId,
            chain: chain,
            delegateId: delegateId,
            tracks: delegateDisplayInfo.additions,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            govBalanceCalculator: GovernanceBalanceCalculator(governanceType: option.type),
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            referendumStringsViewModelFactory: referendumDisplayStringFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = createView(from: presenter, title: title)

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createView(
        from presenter: GovernanceDelegateSetupPresenterProtocol,
        title: LocalizableResource<String>
    ) -> GovernanceDelegateSetupViewController {
        GovernanceDelegateSetupViewController(
            presenter: presenter,
            delegateTitle: title,
            localizationManager: LocalizationManager.shared
        )
    }

    private static func createInteractor(
        for state: GovernanceSharedState
    ) -> GovernanceDelegateSetupInteractor? {
        guard let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        guard
            let subscriptionFactory = state.subscriptionFactory,
            let timelineService = state.createChainTimelineFacade(),
            let lockStateFactory = state.locksOperationFactory,
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: chain.accountRequest()),
            let currencyManager = CurrencyManager.shared,
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId)
        else {
            return nil
        }

        let extrinsicFactory = state.createExtrinsicFactory(for: option)

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        return .init(
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            timelineService: timelineService,
            chainRegistry: state.chainRegistry,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: MultiExtrinsicFeeProxy(),
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }
}
