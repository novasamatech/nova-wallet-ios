import Foundation
import SubstrateSdk
import RobinHood
import SoraFoundation

struct ReferendumDetailsViewFactory {
    static func createView(
        for referendum: ReferendumLocal,
        state: GovernanceSharedState
    ) -> ReferendumDetailsViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: referendum,
                currencyManager: currencyManager,
                state: state
            ),
            let chain = state.settings.value,
            let assetInfo = chain.utilityAssetDisplayInfo() else {
            return nil
        }

        let wireframe = ReferendumDetailsWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let statusViewModelFactory = ReferendumStatusViewModelFactory()

        let indexFormatter = NumberFormatter.index.localizableResource()
        let referendumViewModelFactory = ReferendumsModelFactory(
            referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter),
            statusViewModelFactory: statusViewModelFactory,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            percentFormatter: NumberFormatter.referendumPercent.localizableResource(),
            indexFormatter: indexFormatter
        )

        let referendumStringFactory = ReferendumDisplayStringFactory()
        let timelineViewModelFactory = ReferendumTimelineViewModelFactory(
            statusViewModelFactory: statusViewModelFactory,
            timeFormatter: DateFormatter.shortDateAndTime
        )

        let metadataViewModelFactory = ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter)

        let presenter = ReferendumDetailsPresenter(
            referendum: referendum,
            chain: chain,
            interactor: interactor,
            wireframe: wireframe,
            referendumViewModelFactory: referendumViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumFormatter: indexFormatter,
            referendumStringsFactory: referendumStringFactory,
            referendumTimelineViewModelFactory: timelineViewModelFactory,
            referendumMetadataViewModelFactory: metadataViewModelFactory,
            statusViewModelFactory: statusViewModelFactory,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ReferendumDetailsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for referendum: ReferendumLocal,
        currencyManager: CurrencyManagerProtocol,
        state: GovernanceSharedState
    ) -> ReferendumDetailsInteractor? {
        guard
            let chain = state.settings.value,
            let selectedAccount = SelectedWalletSettings.shared.value.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let chainRegistry = state.chainRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let blockTimeService = state.blockTimeService,
            let subscriptionFactory = state.subscriptionFactory else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let actionDetailsOperationFactory = Gov2ActionOperationFactory(
            requestFactory: requestFactory,
            operationQueue: operationQueue
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let dAppsRepository = JsonFileRepository<[GovernanceDApp]>()

        return ReferendumDetailsInteractor(
            referendum: referendum,
            selectedAccount: selectedAccount,
            chain: chain,
            actionDetailsOperationFactory: actionDetailsOperationFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockTimeService: blockTimeService,
            identityOperationFactory: identityOperationFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            govMetadataLocalSubscriptionFactory: state.govMetadataLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            dAppsRepository: dAppsRepository,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
