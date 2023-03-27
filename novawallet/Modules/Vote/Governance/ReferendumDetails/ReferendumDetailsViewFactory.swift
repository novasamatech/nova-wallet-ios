import Foundation
import SubstrateSdk
import RobinHood
import SoraFoundation

struct ReferendumDetailsViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        initData: ReferendumDetailsInitData
    ) -> ReferendumDetailsViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: initData.referendum,
                currencyManager: currencyManager,
                state: state
            ) else {
            return nil
        }

        let wireframe = ReferendumDetailsWireframe(state: state)

        guard
            let presenter = createPresenter(
                interactor: interactor,
                wireframe: wireframe,
                currencyManager: currencyManager,
                state: state,
                initData: initData
            ) else {
            return nil
        }

        let view = ReferendumDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        interactor: ReferendumDetailsInteractor,
        wireframe: ReferendumDetailsWireframe,
        currencyManager: CurrencyManagerProtocol,
        state: GovernanceSharedState,
        initData: ReferendumDetailsInitData
    ) -> ReferendumDetailsPresenter? {
        guard let stateOption = state.settings.value, let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let chain = stateOption.chain

        guard let assetInfo = chain.utilityAssetDisplayInfo() else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let statusViewModelFactory = ReferendumStatusViewModelFactory()

        let indexFormatter = NumberFormatter.index.localizableResource()
        let referendumStringFactory = ReferendumDisplayStringFactory()

        let referendumViewModelFactory = ReferendumsModelFactory(
            referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter),
            statusViewModelFactory: statusViewModelFactory,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            stringDisplayViewModelFactory: referendumStringFactory,
            percentFormatter: NumberFormatter.referendumPercent.localizableResource(),
            indexFormatter: indexFormatter,
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let timelineViewModelFactory = ReferendumTimelineViewModelFactory(
            statusViewModelFactory: statusViewModelFactory,
            timeFormatter: DateFormatter.shortDateAndTime
        )

        let metadataViewModelFactory = ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter)

        return ReferendumDetailsPresenter(
            chain: chain,
            governanceType: stateOption.type,
            wallet: wallet,
            accountManagementFilter: AccountManagementFilter(),
            initData: initData,
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
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        for referendum: ReferendumLocal,
        currencyManager: CurrencyManagerProtocol,
        state: GovernanceSharedState
    ) -> ReferendumDetailsInteractor? {
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
            selectedAccount: selectedAccount,
            option: option,
            actionDetailsOperationFactory: actionDetailsFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            identityOperationFactory: identityOperationFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            govMetadataLocalSubscriptionFactory: state.govMetadataLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            dAppsProvider: dAppsProvider,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
