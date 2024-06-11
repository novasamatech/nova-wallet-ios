import SoraFoundation

class NetworkDetailsViewModelFactory {
    typealias Details = NetworkDetailsViewLayout.Model
    typealias Section = NetworkDetailsViewLayout.Section
    typealias Node = NetworkDetailsViewLayout.NodeModel

    private let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func createViewModel(
        for network: ChainModel,
        nodes: [ChainNodeModel],
        nodesIndexes: [String: Int],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState]
    ) -> Details {
        Details(
            sections: [
                createSwitchesSection(for: network),
                createAddNodeSection(),
                createNodesSection(
                    with: nodes,
                    chain: network,
                    nodesIndexes: nodesIndexes,
                    connectionStates: connectionStates
                )
            ]
        )
    }

    func createNodesSection(
        with nodes: [ChainNodeModel],
        chain: ChainModel,
        nodesIndexes: [String: Int],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState]
    ) -> Section {
        Section(
            title: "Default Nodes".uppercased(),
            rows: nodes.map {
                .node(
                    createNodeViewModel(
                        for: $0,
                        chain: chain,
                        indexes: nodesIndexes,
                        connectionStates: connectionStates
                    )
                )
            }
        )
    }
}

// MARK: Private

private extension NetworkDetailsViewModelFactory {
    func createSwitchesSection(for network: ChainModel) -> Section {
        Section(
            title: nil,
            rows: [
                .switcher(
                    .init(
                        underlyingViewModel: .init(title: "Enable connection", icon: nil),
                        selectable: network.enabled
                    )
                ),
                .switcher(
                    .init(
                        underlyingViewModel: .init(title: "Auto-balance nodes", icon: nil),
                        selectable: network.connectionMode == .autoBalanced
                    )
                )
            ]
        )
    }

    func createAddNodeSection() -> Section {
        Section(
            title: "Custom nodes".uppercased(),
            rows: [
                .addCustomNode(
                    .init(title: "Add custom node", icon: nil)
                )
            ]
        )
    }

    func createNodeViewModel(
        for node: ChainNodeModel,
        chain: ChainModel,
        indexes: [String: Int],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState]
    ) -> Node {
        let connectionState: Node.ConnectionState

        if let nodeConnectionState = connectionStates[node.url],
           case let .pinged(ping) = nodeConnectionState {
            connectionState = switch ping {
            case 0 ..< 100:
                .pinged(.low("\(ping)"))
            case 100 ..< 500:
                .pinged(.medium("\(ping)"))
            default:
                .pinged(.high("\(ping)"))
            }
        } else {
            connectionState = .connecting(
                R.string.localizable.networkStatusConnecting(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).uppercased()
            )
        }

        return Node(
            index: indexes[node.url]!,
            name: node.name,
            url: node.url,
            connectionState: connectionState,
            selected: chain.selectedNode?.url == node.url
        )
    }
}
