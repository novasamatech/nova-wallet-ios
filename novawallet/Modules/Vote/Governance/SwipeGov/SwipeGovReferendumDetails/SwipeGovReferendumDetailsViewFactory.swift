import Foundation
import Foundation_iOS
import SubstrateSdk
import Operation_iOS

struct SwipeGovReferendumDetailsViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        initData: ReferendumDetailsInitData
    ) -> SwipeGovReferendumDetailsViewProtocol? {
        guard
            let interactor = createInteractor(
                for: initData.referendum,
                state: state
            ) else {
            return nil
        }

        let wireframe = SwipeGovReferendumDetailsWireframe()

        guard
            let presenter = createPresenter(
                interactor: interactor,
                wireframe: wireframe,
                state: state,
                initData: initData
            ) else {
            return nil
        }

        let view = SwipeGovReferendumDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        interactor: SwipeGovReferendumDetailsInteractor,
        wireframe: SwipeGovReferendumDetailsWireframe,
        state: GovernanceSharedState,
        initData: ReferendumDetailsInitData
    ) -> SwipeGovReferendumDetailsPresenter? {
        guard let stateOption = state.settings.value else {
            return nil
        }

        let chain = stateOption.chain

        let statusViewModelFactory = ReferendumStatusViewModelFactory()
        let indexFormatter = NumberFormatter.index.localizableResource()
        let referendumDisplayStringFactory = ReferendumDisplayStringFactory()
        let referendumViewModelFactory = ReferendumsModelFactory(
            referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter),
            statusViewModelFactory: statusViewModelFactory,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            stringDisplayViewModelFactory: referendumDisplayStringFactory,
            percentFormatter: NumberFormatter.referendumPercent.localizableResource(),
            indexFormatter: indexFormatter,
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )
        let metadataViewModelFactory = ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter)

        let universalLinkFactory = ExternalLinkFactory(baseUrl: ApplicationConfig.shared.externalUniversalLinkURL)

        return SwipeGovReferendumDetailsPresenter(
            chain: chain,
            governanceType: stateOption.type,
            interactor: interactor,
            wireframe: wireframe,
            referendumFormatter: indexFormatter,
            referendumViewModelFactory: referendumViewModelFactory,
            referendumMetadataViewModelFactory: metadataViewModelFactory,
            statusViewModelFactory: statusViewModelFactory,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            universalLinkFactory: universalLinkFactory,
            initData: initData,
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )
    }

    private static func createInteractor(
        for referendum: ReferendumLocal,
        state: GovernanceSharedState
    ) -> SwipeGovReferendumDetailsInteractor? {
        guard let option = state.settings.value else {
            return nil
        }

        let chain = option.chain

        let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: chain.accountRequest())

        let chainRegistry = state.chainRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let blockTimeService = state.blockTimeService,
            let blockTimeFactory = state.createBlockTimeOperationFactory(),
            let subscriptionFactory = state.subscriptionFactory else {
            return nil
        }

        let actionDetailsFactory = state.createActionsDetailsFactory(for: option)
        let spendingExtractor = state.createReferendumSpendingExtractor(for: option)

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )

        return SwipeGovReferendumDetailsInteractor(
            referendum: referendum,
            selectedAccount: selectedAccount,
            option: option,
            actionDetailsOperationFactory: actionDetailsFactory,
            spendingAmountExtractor: spendingExtractor,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            identityProxyFactory: identityProxyFactory,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            govMetadataLocalSubscriptionFactory: state.govMetadataLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            operationQueue: operationQueue
        )
    }
}
