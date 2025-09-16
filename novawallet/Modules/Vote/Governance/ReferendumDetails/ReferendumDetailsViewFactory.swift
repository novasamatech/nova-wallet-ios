import Foundation
import SubstrateSdk
import Operation_iOS
import Foundation_iOS

// swiftlint:disable:next function_body_length
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

        let balanceViewModelFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

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

        let timelineViewModelFactory = ReferendumTimelineViewModelFactory(
            statusViewModelFactory: statusViewModelFactory,
            timeFormatter: DateFormatter.shortDateAndTime
        )

        let metadataViewModelFactory = ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter)

        let offchainVotingAvailable = chain.externalApis?.governanceDelegations()?.first != nil

        let endedReferendumProgressViewModelFactory = EndedReferendumProgressViewModelFactory(
            localizedPercentFormatter: NumberFormatter.referendumPercent.localizableResource(),
            offchainVotingAvailable: offchainVotingAvailable
        )

        let referendumVotesFactory = ReferendumVotesViewModelFactoryProvider.factory(
            for: stateOption.type,
            offchainVotingAvailable: offchainVotingAvailable,
            stringFactory: referendumDisplayStringFactory
        )

        let linkFactory = ExternalLinkFactory(baseUrl: ApplicationConfig.shared.externalUniversalLinkURL)

        return ReferendumDetailsPresenter(
            chain: chain,
            governanceType: stateOption.type,
            wallet: wallet,
            accountManagementFilter: AccountManagementFilter(),
            initData: initData,
            interactor: interactor,
            wireframe: wireframe,
            referendumViewModelFactory: referendumViewModelFactory,
            balanceViewModelFacade: balanceViewModelFacade,
            referendumFormatter: indexFormatter,
            referendumVotesFactory: referendumVotesFactory,
            referendumTimelineViewModelFactory: timelineViewModelFactory,
            referendumMetadataViewModelFactory: metadataViewModelFactory,
            endedReferendumProgressViewModelFactory: endedReferendumProgressViewModelFactory,
            statusViewModelFactory: statusViewModelFactory,
            displayAddressViewModelFactory: DisplayAddressViewModelFactory(),
            universalLinkFactory: linkFactory,
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

        let dAppsUrl = ApplicationConfig.shared.governanceDAppsListURL
        let dAppsProvider: AnySingleValueProvider<GovernanceDAppList> =
            JsonDataProviderFactory.shared.getJson(for: dAppsUrl)

        let delegationApi = chain.externalApis?.governanceDelegations()?.first

        let totalVotesFactory: GovernanceTotalVotesFactoryProtocol? = if let delegationApi {
            GovernanceTotalVotesFactory(url: delegationApi.url)
        } else {
            nil
        }

        return ReferendumDetailsInteractor(
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
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            govMetadataLocalSubscriptionFactory: state.govMetadataLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            totalVotesFactory: totalVotesFactory,
            dAppsProvider: dAppsProvider,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
