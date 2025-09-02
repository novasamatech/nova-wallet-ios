import Foundation
import Foundation_iOS
import Operation_iOS

struct SwipeGovSetupViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        initData: ReferendumVotingInitData,
        newVotingPowerClosure: VotingPowerLocalSetClosure?
    ) -> SwipeGovSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let swipeGovSetupInteractor = createInteractor(
                for: state,
                currencyManager: currencyManager
            ),
            let option = state.settings.value
        else {
            return nil
        }

        let wireframe = SwipeGovSetupWireframe(newVotingPowerClosure: newVotingPowerClosure)

        let dataValidatingFactory = GovernanceValidatorFactory.createFromPresentable(wireframe, govType: option.type)

        guard
            let presenter = createPresenter(
                swipeGovSetupInteractor: swipeGovSetupInteractor,
                metaAccount: SelectedWalletSettings.shared.value,
                wireframe: wireframe,
                dataValidatingFactory: dataValidatingFactory,
                initData: initData,
                state: state
            ) else {
            return nil
        }

        let view = SwipeGovSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view

        swipeGovSetupInteractor.presenter = presenter

        return view
    }

    // swiftlint:disable:next function_parameter_count
    private static func createPresenter(
        swipeGovSetupInteractor: SwipeGovSetupInteractorInputProtocol,
        metaAccount: MetaAccountModel,
        wireframe: SwipeGovSetupWireframeProtocol,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        initData: ReferendumVotingInitData,
        state: GovernanceSharedState
    ) -> SwipeGovSetupPresenter? {
        guard
            let option = state.settings.value,
            let assetDisplayInfo = option.chain.utilityAssetDisplayInfo(),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let chain = option.chain

        let votingLockId = state.governanceId(for: option)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let networkViewModelFactory = NetworkViewModelFactory()
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(networkViewModelFactory: networkViewModelFactory)

        let lockChangeViewModelFactory = ReferendumLockChangeViewModelFactory(
            assetDisplayInfo: assetDisplayInfo,
            votingLockId: votingLockId
        )

        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()

        return SwipeGovSetupPresenter(
            chain: chain,
            metaAccount: metaAccount,
            observableState: state.observableState,
            initData: initData,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            referendumStringsViewModelFactory: referendumDisplayStringFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            govBalanceCalculator: GovernanceBalanceCalculator(governanceType: option.type),
            interactor: swipeGovSetupInteractor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        currencyManager: CurrencyManagerProtocol
    ) -> BaseSwipeGovSetupInteractor? {
        guard
            let option = state.settings.value,
            let wallet: MetaAccountModel = SelectedWalletSettings.shared.value,
            let selectedAccount = wallet.fetchMetaChainAccount(for: option.chain.accountRequest()),
            let lockStateFactory = state.locksOperationFactory,
            let blockTimeService = state.blockTimeService,
            let blockTimeFactory = state.createBlockTimeOperationFactory(),
            let connection = state.chainRegistry.getConnection(for: option.chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: option.chain.chainId)
        else {
            return nil
        }

        let repository = SwipeGovRepositoryFactory.createVotingPowerRepository(
            for: option.chain.chainId,
            metaId: wallet.metaId,
            using: UserDataStorageFacade.shared
        )

        return SwipeGovSetupInteractor(
            repository: repository,
            selectedAccount: selectedAccount,
            observableState: state.observableState,
            chain: option.chain,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            lockStateFactory: lockStateFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
