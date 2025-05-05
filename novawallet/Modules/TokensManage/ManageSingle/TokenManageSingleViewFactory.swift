import Foundation
import Foundation_iOS
import Keystore_iOS

struct TokenManageSingleViewFactory {
    static func createView(
        for token: MultichainToken,
        chains: [ChainModel.Id: ChainModel]
    ) -> TokenManageSingleViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let formatter = NumberFormatter.positiveQuantity.localizableResource()
        let assetIconViewModelFactory = AssetIconViewModelFactory()

        let viewModelFactory = TokensManageViewModelFactory(
            quantityFormater: formatter,
            assetIconViewModelFactory: assetIconViewModelFactory
        )

        let presenter = TokenManageSinglePresenter(
            interactor: interactor,
            token: token,
            chains: chains,
            viewModelFactory: viewModelFactory,
            networkViewModelFactory: NetworkViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = TokenManageSingleViewController(presenter: presenter)
        let height = TokenManageSingleMeasurement.estimatePreferredHeight(for: token.instances.count)
        view.preferredContentSize = CGSize(width: 0, height: height)

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
