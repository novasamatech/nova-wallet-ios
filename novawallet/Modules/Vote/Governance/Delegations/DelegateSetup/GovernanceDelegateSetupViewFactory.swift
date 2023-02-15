import Foundation
import SoraFoundation
import RobinHood

struct GovernanceDelegateSetupViewFactory {
    static func createAddDelegationView(
        for state: GovernanceSharedState,
        delegateId: AccountId,
        delegateDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>
    ) -> GovernanceDelegateSetupViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.governanceReferendumsAddDelegation(
                preferredLanguages: locale.rLanguages
            )
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
            R.string.localizable.govEditDelegation(
                preferredLanguages: locale.rLanguages
            )
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

        let referendumStringsViewModelFactory = ReferendumDisplayStringFactory()

        let localizationManager = LocalizationManager.shared

        let dataValidatingFactory = GovernanceValidatorFactory.createFromPresentable(wireframe)

        let presenter = GovernanceDelegateSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccountId: selectedAccount.accountId,
            chain: chain,
            delegateId: delegateId,
            tracks: delegateDisplayInfo.additions,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            referendumStringsViewModelFactory: referendumStringsViewModelFactory,
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
            let blockTimeService = state.blockTimeService,
            let lockStateFactory = state.locksOperationFactory,
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: chain.accountRequest()),
            let blockTimeOperationFactory = state.createBlockTimeOperationFactory(),
            let currencyManager = CurrencyManager.shared,
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId)
        else {
            return nil
        }

        let extrinsicFactory = state.createExtrinsicFactory(for: option)

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: operationManager
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        return .init(
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeOperationFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }
}
