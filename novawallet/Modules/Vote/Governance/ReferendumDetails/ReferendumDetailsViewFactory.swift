import Foundation
import SubstrateSdk
import RobinHood
import SoraFoundation

struct ReferendumDetailsViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        referendum: ReferendumLocal,
        accountVotes: ReferendumAccountVoteLocal?,
        metadata: ReferendumMetadataLocal?
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
            indexFormatter: indexFormatter,
            quantityFormatter: NumberFormatter.quantity.localizableResource()
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
            accountManagementFilter: AccountManagementFilter(),
            accountVotes: accountVotes,
            metadata: metadata,
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
        guard let chain = state.settings.value else {
            return nil
        }

        let chainRegistry = state.chainRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let blockTimeService = state.blockTimeService,
            let subscriptionFactory = state.subscriptionFactory,
            let actionDetailsFactory = state.createActionsDetailsFactory(for: chain) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let dAppsUrl = ApplicationConfig.shared.governanceDAppsListURL
        let dAppsProvider: AnySingleValueProvider<GovernanceDAppList> =
            JsonDataProviderFactory.shared.getJson(for: dAppsUrl)

        return ReferendumDetailsInteractor(
            referendum: referendum,
            walletSettings: SelectedWalletSettings.shared,
            chain: chain,
            actionDetailsOperationFactory: actionDetailsFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockTimeService: blockTimeService,
            identityOperationFactory: identityOperationFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            govMetadataLocalSubscriptionFactory: state.govMetadataLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            dAppsProvider: dAppsProvider,
            eventCenter: EventCenter.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
