import Foundation_iOS

private typealias ModalActionsContext = (
    actions: [LocalizableResource<ActionManageViewModel>],
    context: ModalPickerClosureContext
)

final class NetworkDetailsPresenter {
    weak var view: NetworkDetailsViewProtocol?
    let wireframe: NetworkDetailsWireframeProtocol
    let interactor: NetworkDetailsInteractorInputProtocol

    private var chain: ChainModel
    private var sortedNodes: [ChainNodeModel] = []
    private var connectionStates: [String: ConnectionState] = [:]
    private var nodesIds: [String: UUID] = [:]
    private var nodes: [UUID: ChainNodeModel] = [:]
    private var selectedNode: ChainNodeModel?

    private let viewModelFactory: NetworkDetailsViewModelFactory

    init(
        interactor: NetworkDetailsInteractorInputProtocol,
        wireframe: NetworkDetailsWireframeProtocol,
        chain: ChainModel,
        viewModelFactory: NetworkDetailsViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

// MARK: NetworkDetailsPresenterProtocol

extension NetworkDetailsPresenter: NetworkDetailsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func setNetwork(enabled: Bool) {
        interactor.setSetNetworkConnection(enabled: enabled)
    }

    func setAutoBalance(enabled: Bool) {
        interactor.setAutoBalance(enabled: enabled)
    }

    func addNode() {
        wireframe.showAddNode(
            from: view,
            chainId: chain.chainId
        )
    }

    func selectNode(with id: UUID) {
        guard let node = nodes[id] else {
            return
        }

        interactor.selectNode(node)
    }

    func manageNetwork() {
        openManageNetwork()
    }
}

// MARK: NetworkDetailsInteractorOutputProtocol

extension NetworkDetailsPresenter: NetworkDetailsInteractorOutputProtocol {
    func didReceive(
        _ chain: ChainModel,
        filteredNodes: Set<ChainNodeModel>
    ) {
        self.chain = chain

        sortedNodes = filteredNodes.sorted { $0.order < $1.order }

        if sortedNodes.count == 1, let selectedNode = sortedNodes.first {
            self.selectedNode = selectedNode
        } else if case let .manual(selectedNode) = chain.connectionMode {
            self.selectedNode = selectedNode
        }

        indexNodes(sortedNodes)
        provideViewModel()
    }

    func didReceive(
        _ connectionState: ConnectionState,
        for nodeURL: String,
        selected: Bool
    ) {
        guard
            let nodeId = nodesIds[nodeURL],
            let node = nodes[nodeId]
        else {
            return
        }

        if selected {
            let oldSelectedNode = selectedNode
            selectedNode = node

            if let oldSelectedNode {
                provideNodeViewModel(for: oldSelectedNode)
            }
        } else if selectedNode?.url == nodeURL {
            selectedNode = nil
        }

        connectionStates[nodeURL] = connectionState

        switch connectionState {
        case .connecting, .disconnected, .pinged, .unknown:
            provideNodeViewModel(for: node)
        case .connected:
            break
        }
    }

    func didDeleteNetwork() {
        wireframe.showNetworksList(from: view)
    }

    func didReceive(_ error: any Error) {
        wireframe.present(
            error: error,
            from: view,
            locale: selectedLocale
        )
    }
}

// MARK: Private

private extension NetworkDetailsPresenter {
    func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            for: chain,
            nodes: sortedNodes,
            selectedNode: selectedNode,
            nodesIds: nodesIds,
            connectionStates: connectionStates,
            onTapEdit: editNode(with:),
            onTapMore: manageNode(with:)
        )
        view?.update(with: viewModel)
    }

    func provideNodeViewModel(for node: ChainNodeModel) {
        let notSingleUserNode = chain.nodes
            .filter { $0.source == .user }
            .count > 1
        let notEmptyRemoteModes = !chain.nodes
            .filter { $0.source == .remote }
            .isEmpty

        let deletionAllowed = notSingleUserNode || notEmptyRemoteModes

        let viewModel = switch node.source {
        case .user:
            viewModelFactory.createAddNodeSection(
                with: [node],
                selectedNode: selectedNode,
                chain: chain,
                nodesIds: nodesIds,
                connectionStates: connectionStates,
                deletionAllowed: deletionAllowed,
                onTapEdit: editNode(with:),
                onTapMore: manageNode(with:)
            )
        case .remote:
            viewModelFactory.createNodesSection(
                with: [node],
                selectedNode: selectedNode,
                chain: chain,
                nodesIds: nodesIds,
                connectionStates: connectionStates
            )
        }

        view?.updateNodes(with: viewModel)
    }

    func indexNodes(_ sortedNodes: [ChainNodeModel]) {
        nodes = [:]

        sortedNodes.forEach { node in
            if nodesIds[node.url] == nil {
                nodesIds[node.url] = UUID()
            }

            let id = nodesIds[node.url]!

            nodes[id] = node
        }
    }

    func manageNode(with id: UUID) {
        guard let node = nodes[id] else { return }

        wireframe.showManageNode(
            from: view,
            node: node,
            onNodeEdit: { [weak self] in
                guard let self else { return }

                wireframe.showEditNode(
                    from: view,
                    node: node,
                    chainId: chain.chainId
                )
            },
            onNodeDelete: { [weak self] in
                self?.openDeleteNodeAlert(for: node)
            }
        )
    }

    func editNode(with id: UUID) {
        guard let node = nodes[id] else { return }

        wireframe.showEditNode(
            from: view,
            node: node,
            chainId: chain.chainId
        )
    }

    func openManageNetwork() {
        guard let view else {
            return
        }

        let modalActionsContext = createModalActionsContext()

        wireframe.presentActionsManage(
            from: view,
            actions: modalActionsContext.actions,
            title: LocalizableResource { locale in
                R.string.localizable.networkManageTitle(preferredLanguages: locale.rLanguages)
            },
            delegate: self,
            context: modalActionsContext.context
        )
    }

    func openDeleteNodeAlert(for node: ChainNodeModel) {
        let alertViewModel = AlertPresentableViewModel(
            title: R.string.localizable.networkNodeDeleteAlertTitle(
                preferredLanguages: selectedLocale.rLanguages
            ),
            message: R.string.localizable.networkNodeDeleteAlertDescription(
                node.name,
                preferredLanguages: selectedLocale.rLanguages
            ),
            actions: [
                .init(
                    title: R.string.localizable.commonCancel(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    style: .cancel
                ),
                .init(
                    title: R.string.localizable.commonDelete(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    style: .destructive,
                    handler: {
                        [weak self] in self?.interactor.deleteNode(node)
                    }
                )
            ],
            closeAction: nil
        )
        wireframe.present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }

    func openDeleteNetworkAlert() {
        let alertViewModel = AlertPresentableViewModel(
            title: R.string.localizable.networkManageDeleteAlertTitle(
                preferredLanguages: selectedLocale.rLanguages
            ),
            message: R.string.localizable.networkManageDeleteAlertDescription(
                preferredLanguages: selectedLocale.rLanguages
            ),
            actions: [
                .init(
                    title: R.string.localizable.commonCancel(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    style: .cancel
                ),
                .init(
                    title: R.string.localizable.commonDelete(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    style: .destructive,
                    handler: {
                        [weak self] in self?.interactor.deleteNetwork()
                    }
                )
            ],
            closeAction: nil
        )
        wireframe.present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }

    func createModalActionsContext() -> ModalActionsContext {
        let actionViewModels: [LocalizableResource<ActionManageViewModel>] = [
            LocalizableResource { locale in
                ActionManageViewModel(
                    icon: R.image.iconPencil(),
                    title: R.string.localizable.networkManageEdit(preferredLanguages: locale.rLanguages)
                )
            },
            LocalizableResource { locale in
                ActionManageViewModel(
                    icon: R.image.iconDelete(),
                    title: R.string.localizable.networkManageDelete(preferredLanguages: locale.rLanguages),
                    style: .destructive
                )
            }
        ]

        let context = ModalPickerClosureContext { [weak self] index in
            guard
                let self,
                let manageAction = ManageActions(rawValue: index)
            else {
                return
            }

            switch manageAction {
            case .edit:
                guard let selectedNode else { return }

                wireframe.showEditNetwork(
                    from: view,
                    network: chain,
                    selectedNode: selectedNode
                )
            case .delete:
                openDeleteNetworkAlert()
            }
        }

        return (actionViewModels, context)
    }
}

// MARK: ModalPickerViewControllerDelegate

extension NetworkDetailsPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard let context = context as? ModalPickerClosureContext else {
            return
        }
        context.process(selectedIndex: index)
    }
}

// MARK: Localizable

extension NetworkDetailsPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else {
            return
        }
        provideViewModel()
    }
}

extension NetworkDetailsPresenter {
    enum ConnectionState: Equatable {
        case connecting
        case connected
        case disconnected
        case pinged(Int)
        case unknown
    }
}

private extension NetworkDetailsPresenter {
    enum ManageActions: Int {
        case edit = 0
        case delete
    }
}
