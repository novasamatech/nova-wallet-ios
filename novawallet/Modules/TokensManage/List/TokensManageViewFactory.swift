import Foundation
import Foundation_iOS
import Keystore_iOS

struct TokensManageViewFactory {
    static func createView() -> TokensManageViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = TokensManageWireframe()

        let formatter = NumberFormatter.positiveQuantity.localizableResource()
        let assetIconViewModelFactory = AssetIconViewModelFactory()

        let viewModelFactory = TokensManageViewModelFactory(
            quantityFormater: formatter,
            assetIconViewModelFactory: assetIconViewModelFactory
        )

        let presenter = TokensManagePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = TokensManageViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> TokensManageInteractor? {
        let repository = SubstrateRepositoryFactory().createChainRepository()
        let eventCenter = EventCenter.shared
        let settingsManager = SettingsManager.shared

        return .init(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            eventCenter: eventCenter,
            settingsManager: settingsManager,
            repository: repository,
            repositoryFactory: SubstrateRepositoryFactory(storageFacade: SubstrateDataStorageFacade.shared),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
