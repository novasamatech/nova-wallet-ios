import Foundation
import Foundation_iOS
import Keystore_iOS

struct TokensManageViewFactory {
    static func createView() -> TokensManageViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = TokensManageWireframe()

        let formatter = NumberFormatter.quantity.localizableResource()
        let assetIconViewModelFactory = AssetIconViewModelFactory()

        let viewModelFactory = TokensManageViewModelFactory(
            quantityFormater: formatter,
            assetIconViewModelFactory: assetIconViewModelFactory,
            networkViewModelFactory: NetworkViewModelFactory()
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
        guard let selectedMetaId = SelectedWalletSettings.shared.value?.metaId else {
            return nil
        }

        let settingsRepository = AssetVisibilityRepositoryFactory.createSettingsRepository(
            for: selectedMetaId,
            using: UserDataStorageFacade.shared
        )

        return .init(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            selectedWalletSettings: SelectedWalletSettings.shared,
            settingsManager: SettingsManager.shared,
            assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactory.shared,
            visibilityWriter: AssetVisibilityWriter.shared,
            settingsRepository: settingsRepository,
            defaultAssetsProvider: DefaultAssetsProvider.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            settingsSaveQueue: OperationManagerFacade.assetVisibilityQueue,
            logger: Logger.shared
        )
    }
}
