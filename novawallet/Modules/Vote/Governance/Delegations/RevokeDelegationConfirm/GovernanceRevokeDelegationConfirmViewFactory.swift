import Foundation
import Operation_iOS
import Foundation_iOS

struct GovRevokeDelegationConfirmViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        selectedTracks: [GovernanceTrackInfoLocal],
        delegate: GovernanceDelegateFlowDisplayInfo<AccountId>
    ) -> GovernanceRevokeDelegationConfirmViewProtocol? {
        guard
            let interactor = createInteractor(for: state, delegateId: delegate.additions),
            let option = state.settings.value else {
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

        let wireframe = GovRevokeDelegationConfirmWireframe(state: state)

        let votingLockId = state.governanceId(for: option)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let lockChangeViewModelFactory = ReferendumLockChangeViewModelFactory(
            assetDisplayInfo: assetInfo,
            votingLockId: votingLockId
        )

        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()

        let dataValidatingFactory = GovernanceValidatorFactory.createFromPresentable(wireframe, govType: option.type)

        let presenter = GovRevokeDelegationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            selectedAccount: selectedAccount,
            selectedTracks: selectedTracks,
            delegationInfo: delegate,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumStringsViewModelFactory: referendumDisplayStringFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            trackViewModelFactory: GovernanceTrackViewModelFactory(),
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = createView(from: presenter)

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createView(
        from presenter: GovernanceRevokeDelegationConfirmPresenterProtocol
    ) -> GovRevokeDelegationConfirmViewController {
        GovRevokeDelegationConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        delegateId: AccountId
    ) -> GovRevokeDelegationConfirmInteractor? {
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

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: option.chain)

        let signer = SigningWrapperFactory.createSigner(from: selectedAccount)

        return .init(
            selectedAccount: selectedAccount,
            delegateId: delegateId,
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
