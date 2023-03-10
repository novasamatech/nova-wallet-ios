import Foundation
import SoraFoundation
import RobinHood

struct GovernanceDelegateConfirmViewFactory {
    static func createAddDelegationView(
        for state: GovernanceSharedState,
        delegation: GovernanceNewDelegation,
        delegationDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>
    ) -> GovernanceDelegateConfirmViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.governanceReferendumsAddDelegation(
                preferredLanguages: locale.rLanguages
            )
        }

        return createModule(
            for: state,
            delegation: delegation,
            delegationDisplayInfo: delegationDisplayInfo,
            title: title
        )
    }

    static func createEditDelegationView(
        for state: GovernanceSharedState,
        delegation: GovernanceNewDelegation,
        delegationDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>
    ) -> GovernanceDelegateConfirmViewProtocol? {
        let title = LocalizableResource { locale in
            R.string.localizable.govEditDelegation(
                preferredLanguages: locale.rLanguages
            )
        }

        return createModule(
            for: state,
            delegation: delegation,
            delegationDisplayInfo: delegationDisplayInfo,
            title: title
        )
    }

    private static func createModule(
        for state: GovernanceSharedState,
        delegation: GovernanceNewDelegation,
        delegationDisplayInfo: GovernanceDelegateFlowDisplayInfo<[GovernanceTrackInfoLocal]>,
        title: LocalizableResource<String>
    ) -> GovernanceDelegateConfirmViewProtocol? {
        guard let interactor = createInteractor(for: state), let option = state.settings.value else {
            return nil
        }

        let chain = option.chain
        let optAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(for: chain.accountRequest())

        guard let selectedAccount = optAccount else {
            return nil
        }

        guard let assetInfo = chain.utilityAssetDisplayInfo(), let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = GovernanceDelegateConfirmWireframe(state: state)

        let votingLockId = state.governanceId(for: option)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let lockChangeViewModelFactory = ReferendumLockChangeViewModelFactory(
            assetDisplayInfo: assetInfo,
            votingLockId: votingLockId
        )

        let referendumStringsViewModelFactory = ReferendumDisplayStringFactory()

        let dataValidatingFactory = GovernanceValidatorFactory.createFromPresentable(wireframe)

        let presenter = GovernanceDelegateConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            selectedAccount: selectedAccount,
            delegation: delegation,
            delegationInfo: delegationDisplayInfo,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumStringsViewModelFactory: referendumStringsViewModelFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            trackViewModelFactory: GovernanceTrackViewModelFactory(),
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = createView(from: presenter, title: title)

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createView(
        from presenter: GovernanceDelegateConfirmPresenterProtocol,
        title: LocalizableResource<String>
    ) -> GovernanceDelegateConfirmViewController {
        GovernanceDelegateConfirmViewController(
            presenter: presenter,
            delegateTitle: title,
            localizationManager: LocalizationManager.shared
        )
    }

    private static func createInteractor(
        for state: GovernanceSharedState
    ) -> GovernanceDelegateConfirmInteractor? {
        guard
            let option = state.settings.value,
            let subscriptionFactory = state.subscriptionFactory,
            let blockTimeService = state.blockTimeService,
            let lockStateFactory = state.locksOperationFactory,
            let wallet = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: option.chain.accountRequest()),
            let blockTimeOperationFactory = state.createBlockTimeOperationFactory(),
            let currencyManager = CurrencyManager.shared,
            let connection = state.chainRegistry.getConnection(for: option.chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: option.chain.chainId)
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
        ).createService(account: selectedAccount.chainAccount, chain: option.chain)

        let signer = SigningWrapperFactory.createSigner(from: selectedAccount)

        return .init(
            selectedAccount: selectedAccount,
            chain: option.chain,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeOperationFactory,
            chainRegistry: state.chainRegistry,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: MultiExtrinsicFeeProxy(),
            signer: signer,
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }
}
