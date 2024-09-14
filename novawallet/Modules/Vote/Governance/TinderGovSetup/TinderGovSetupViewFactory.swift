import Foundation
import SoraFoundation
import Operation_iOS

struct TinderGovSetupViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        referendum: ReferendumIdLocal,
        initData: ReferendumVotingInitData
    ) -> TinderGovSetupViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                referendum: referendum,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = TinderGovSetupWireframe()

        let dataValidatingFactory = GovernanceValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        guard
            let presenter = createPresenter(
                from: interactor,
                metaAccount: SelectedWalletSettings.shared.value,
                wireframe: wireframe,
                dataValidatingFactory: dataValidatingFactory,
                referendum: referendum,
                initData: initData,
                state: state
            ) else {
            return nil
        }

        let view = TinderGovSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    // swiftlint:disable:next function_parameter_count
    private static func createPresenter(
        from interactor: TinderGovSetupInteractor,
        metaAccount: MetaAccountModel,
        wireframe: TinderGovSetupWireframeProtocol,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
        referendum _: ReferendumIdLocal,
        initData: ReferendumVotingInitData,
        state: GovernanceSharedState
    ) -> TinderGovSetupPresenter? {
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

        return TinderGovSetupPresenter(
            chain: chain,
            metaAccount: metaAccount,
            initData: initData,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumFormatter: NumberFormatter.index.localizableResource(),
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            referendumStringsViewModelFactory: referendumDisplayStringFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
    }

    // swiftlint:disable function_body_length
    private static func createInteractor(
        for state: GovernanceSharedState,
        referendum: ReferendumIdLocal,
        currencyManager: CurrencyManagerProtocol
    ) -> TinderGovSetupInteractor? {
        guard
            let option = state.settings.value,
            let wallet: MetaAccountModel = SelectedWalletSettings.shared.value
        else {
            return nil
        }

        let chain = option.chain

        guard
            let selectedAccount = wallet.fetchMetaChainAccount(for: chain.accountRequest()),
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
        let storageFacade: StorageFacadeProtocol = SubstrateDataStorageFacade.shared

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: storageFacade
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        let mapper = VotingPowerMapper()

        let filter = NSPredicate.votingPower(
            for: option.chain.chainId,
            metaId: wallet.metaId
        )
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return TinderGovSetupInteractor(
            repository: AnyDataProviderRepository(repository),
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
