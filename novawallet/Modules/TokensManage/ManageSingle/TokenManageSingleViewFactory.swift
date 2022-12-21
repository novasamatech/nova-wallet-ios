import Foundation
import SoraFoundation

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
        let viewModelFactory = TokensManageViewModelFactory(quantityFormater: formatter)

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

        return .init(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: repository,
            repositoryFactory: SubstrateRepositoryFactory(storageFacade: SubstrateDataStorageFacade.shared),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
