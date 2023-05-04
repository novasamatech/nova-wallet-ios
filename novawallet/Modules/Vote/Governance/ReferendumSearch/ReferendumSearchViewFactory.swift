import Foundation
import SoraFoundation

struct ReferendumSearchViewFactory {
    static func createView(
        initialState: SearchReferendumsState,
        governanceState: GovernanceSharedState,
        delegate: ReferendumSearchDelegate?
    ) -> ReferendumSearchViewProtocol? {
        guard let interactor = createInteractor(
            for: governanceState,
            initialState: initialState,
            wallet: SelectedWalletSettings.shared.value
        ) else {
            return nil
        }
        let wireframe = ReferendumSearchWireframe(state: governanceState)
        let statusViewModelFactory = ReferendumStatusViewModelFactory()
        let indexFormatter = NumberFormatter.index.localizableResource()
        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ReferendumsModelFactory(
            referendumMetadataViewModelFactory: ReferendumMetadataViewModelFactory(indexFormatter: indexFormatter),
            statusViewModelFactory: statusViewModelFactory,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            stringDisplayViewModelFactory: ReferendumDisplayStringFactory(),
            percentFormatter: NumberFormatter.referendumPercent.localizableResource(),
            indexFormatter: NumberFormatter.index.localizableResource(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = ReferendumSearchPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            statusViewModelFactory: ReferendumStatusViewModelFactory(),
            delegate: delegate,
            logger: Logger.shared
        )

        let view = ReferendumSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        initialState: SearchReferendumsState,
        wallet: MetaAccountModel
    ) -> ReferendumSearchInteractor? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationQueue = OperationQueue()
        let logger = Logger.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let serviceFactory = GovernanceServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            eventCenter: EventCenter.shared,
            operationQueue: operationQueue,
            logger: logger
        )

        let applicationHandler = SecurityLayerService.shared.applicationHandlingProxy.addApplicationHandler()

        return ReferendumSearchInteractor(
            initialState: initialState,
            selectedMetaAccount: wallet,
            governanceState: state,
            chainRegistry: chainRegistry,
            serviceFactory: serviceFactory,
            applicationHandler: applicationHandler,
            operationQueue: operationQueue
        )
    }
}
