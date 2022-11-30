import Foundation
import SubstrateSdk
import RobinHood
import SoraFoundation

struct ReferendumVoteSetupViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        referendum: ReferendumIdLocal,
        initData: ReferendumVotingInitData
    ) -> ReferendumVoteSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                referendum: referendum,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = ReferendumVoteSetupWireframe(state: state)

        let dataValidatingFactory = GovernanceValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        guard
            let presenter = createPresenter(
                from: interactor,
                wireframe: wireframe,
                dataValidatingFactory: dataValidatingFactory,
                referendum: referendum,
                initData: initData,
                state: state
            ) else {
            return nil
        }

        let view = ReferendumVoteSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        from interactor: ReferendumVoteSetupInteractor,
        wireframe: ReferendumVoteSetupWireframeProtocol,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        referendum: ReferendumIdLocal,
        initData: ReferendumVotingInitData,
        state: GovernanceSharedState
    ) -> ReferendumVoteSetupPresenter? {
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

        let referendumStringsViewModelFactory = ReferendumDisplayStringFactory()

        return ReferendumVoteSetupPresenter(
            chain: chain,
            referendumIndex: referendum,
            initData: initData,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumFormatter: NumberFormatter.index.localizableResource(),
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            referendumStringsViewModelFactory: referendumStringsViewModelFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        referendum: ReferendumIdLocal,
        currencyManager: CurrencyManagerProtocol
    ) -> ReferendumVoteSetupInteractor? {
        let wallet: MetaAccountModel? = SelectedWalletSettings.shared.value

        guard let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        guard
            let selectedAccount = wallet?.fetchMetaChainAccount(for: chain.accountRequest()),
            let subscriptionFactory = state.subscriptionFactory,
            let lockStateFactory = state.locksOperationFactory,
            let blockTimeService = state.blockTimeService,
            let blockTimeFactory = state.createBlockTimeOperationFactory()
        else {
            return nil
        }

        let extrinsicFactory = state.createExtrinsicFactory(for: option)

        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: operationManager
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        return ReferendumVoteSetupInteractor(
            referendumIndex: referendum,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
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
