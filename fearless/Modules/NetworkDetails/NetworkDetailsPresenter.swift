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
    private var autoSelectNodes: Bool?

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
        guard
            let selectedNode = chainModel.nodes.first, // TODO: selectedConnection.node
            let autoSelectNodes = autoSelectNodes
        else {
            return
        }

        let viewModel = viewModelFactory.createViewModel(
            chainModel: chainModel,
            autoSelectNodes: autoSelectNodes,
            selectedNode: selectedNode,
            locale: selectedLocale
        )
        view?.reload(viewModel: viewModel)
    }
}

extension NetworkDetailsPresenter: NetworkDetailsPresenterProtocol {
    func setup() {
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

        // TODO:
//        if selectedConnection.node != node {
//            pendingCompletion = true
//
//            interactor.connect(to: node)
//        }
    }

    func handleAutoSelectNodesToggle(isOn: Bool) {
        interactor.toggleAutoSelectNodes(isOn: isOn)
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

    func didReceiveAutoSelectNodes(_ auto: Bool) {
        autoSelectNodes = auto
        updateView()
    }
}
