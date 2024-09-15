import Foundation
import SoraFoundation
import Operation_iOS

struct TinderGovSetupViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        referendum _: ReferendumIdLocal,
        initData: ReferendumVotingInitData
    ) -> TinderGovSetupViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let storageFacade = SubstrateDataStorageFacade.shared

        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                currencyManager: currencyManager,
                storageFacade: storageFacade,
                operationQueue: operationQueue
            )
        else {
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
                interactor: interactor,
                metaAccount: SelectedWalletSettings.shared.value,
                wireframe: wireframe,
                dataValidatingFactory: dataValidatingFactory,
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
        interactor: BaseTinderGovSetupInteractor,
        metaAccount: MetaAccountModel,
        wireframe: TinderGovSetupWireframeProtocol,
        dataValidatingFactory: GovernanceValidatorFactoryProtocol,
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
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            referendumStringsViewModelFactory: referendumDisplayStringFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        currencyManager: CurrencyManagerProtocol,
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) -> BaseTinderGovSetupInteractor? {
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

        let votingPowerRepository = createVotingPowerRepository(
            for: state,
            wallet: wallet,
            storageFacade: storageFacade
        )

        return TinderGovSetupInteractor(
            repository: votingPowerRepository,
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
            operationQueue: operationQueue
        )
    }

    private static func createVotingPowerRepository(
        for state: GovernanceSharedState,
        wallet: MetaAccountModel,
        storageFacade: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<VotingPowerLocal> {
        let mapper = VotingPowerMapper()

        let filter = NSPredicate.votingPower(
            for: state.settings.value.chain.chainId,
            metaId: wallet.metaId
        )
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }
}
