import Foundation
import SoraFoundation

struct SwipeGovVotingConfirmViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        initData: ReferendumVotingInitData
    ) -> SwipeGovVotingConfirmViewProtocol? {
        guard let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                votingItems: initData.votingItems ?? [],
                currencyManager: currencyManager
            ),
            let assetDisplayInfo = chain.utilityAsset()?.displayInfo(with: chain.icon),
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chain.accountRequest()
            )
        else {
            return nil
        }

        let votingLockId = state.governanceId(for: option)

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let lockChangeViewModelFactory = ReferendumLockChangeViewModelFactory(
            assetDisplayInfo: assetDisplayInfo,
            votingLockId: votingLockId
        )

        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()

        let wireframe = SwipeGovVotingConfirmWireframe()

        let dataValidatingFactory = GovernanceValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = SwipeGovVotingConfirmPresenter(
            initData: initData,
            chain: chain,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumFormatter: NumberFormatter.index.localizableResource(),
            referendumStringsViewModelFactory: referendumDisplayStringFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = SwipeGovVotingConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    // swiftlint:disable:next function_body_length
    private static func createInteractor(
        for state: GovernanceSharedState,
        votingItems: [VotingBasketItemLocal],
        currencyManager: CurrencyManagerProtocol
    ) -> SwipeGovVotingConfirmInteractor? {
        guard let wallet: MetaAccountModel = SelectedWalletSettings.shared.value else {
            return nil
        }

        guard let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        guard
            let selectedAccount = wallet.fetchMetaChainAccount(for: chain.accountRequest()),
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

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        let repository = SwipeGovRepositoryFactory.createVotingItemsRepository(
            for: chain.chainId,
            metaId: wallet.metaId,
            using: SubstrateDataStorageFacade.shared
        )

        let votingItemsDict = votingItems.reduce(into: [:]) { $0[$1.referendumId] = $1 }

        return SwipeGovVotingConfirmInteractor(
            observableState: state.observableState,
            repository: repository,
            votingItems: votingItemsDict,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            signer: signer,
            feeProxy: MultiExtrinsicFeeProxy(),
            lockStateFactory: lockStateFactory,
            logger: Logger.shared,
            operationQueue: operationQueue
        )
    }
}