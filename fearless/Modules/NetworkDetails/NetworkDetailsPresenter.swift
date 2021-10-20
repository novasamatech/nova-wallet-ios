import Foundation
import SoraFoundation

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol
    let viewModelFactory: NetworkDetailsViewModelFactoryProtocol
    let chainModel: ChainModel
    let localizationManager: LocalizationManagerProtocol?

    private let defaultNodes: [ChainNodeModel]
    private var selectedConnection: ChainConnection?

    init(
        interactor: NetworkDetailsInteractorInputProtocol,
        wireframe: NetworkDetailsWireframeProtocol,
        viewModelFactory: NetworkDetailsViewModelFactoryProtocol,
        chainModel: ChainModel,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chainModel = chainModel
        self.localizationManager = localizationManager
        defaultNodes = Array(chainModel.nodes)
    }

    private func updateView() {
        let viewModel = viewModelFactory.createViewModel(chainModel: chainModel, locale: selectedLocale)
        view?.reload(viewModel: viewModel)
    }
}

extension NetworkDetailsPresenter: NetworkDetailsPresenterProtocol {
    func setup() {
        updateView()
        interactor.setup()
    }

    func handleActionButton() {
        wireframe.showAddConnection(from: view)
    }

    func handleDefaultNodeInfo(at index: Int) {
        let node = defaultNodes[index]
        let connection = ConnectionItem(title: node.name, url: node.url, type: .genericSubstrate)

        wireframe.showNodeInfo(
            connectionItem: connection,
            mode: .none,
            from: view
        )
    }

    func handleSelectDefaultNode(at index: Int) {
        let node = defaultNodes[index]

//        if selectedConnectionItem.node != node {
//            pendingCompletion = true
//
//            interactor.select(connection: connection)
//        }
    }
}

extension NetworkDetailsPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}

extension NetworkDetailsPresenter: NetworkDetailsInteractorOutputProtocol {
    func didReceiveSelectedConnection(_ connection: ChainConnection?) {
        selectedConnection = connection
        updateView()
    }
}
