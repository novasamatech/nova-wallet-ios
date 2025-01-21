import Foundation
import SoraFoundation

struct MythosStakingSetupViewFactory {
    static func createView(
        for state: MythosStakingSharedStateProtocol
    ) -> CollatorStakingSetupViewProtocol? {
        guard let interactor = createInteractor(for: state) else {
            return nil
        }

        let wireframe = MythosStakingSetupWireframe()

        let presenter = MythosStakingSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        let view = CollatorStakingSetupViewController(
            presenter: presenter,
            localizableTitle: LocalizableResource { _ in "" },
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: MythosStakingSharedStateProtocol
    ) -> MythosStakingSetupInteractor? {
        let chain = state.stakingOption.chainAsset.chain

        guard
            let selectedAccount = SelectedWalletSettings.shared.value.fetch(
                for: state.stakingOption.chainAsset.chain.accountRequest()
            ),
            let stakingDetailsService = state.detailsSyncService,
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let repositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(
            account: selectedAccount,
            chain: chain
        )

        return MythosStakingSetupInteractor(
            chainAsset: state.stakingOption.chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            preferredCollatorFactory: nil, // TODO: Refactor and integrate preferred collators
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            connection: connection,
            runtimeProvider: runtimeProvider,
            repositoryFactory: repositoryFactory,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
