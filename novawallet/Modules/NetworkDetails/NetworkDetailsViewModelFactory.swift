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
        nodes: [MeasuredNode],
        nodesIndexes: [String: Int]
    ) -> Details {
        Details(
            sections: [
                createSwitchesSection(for: network),
                createAddNodeSection(),
                createNodesSection(with: nodes, nodesIndexes: nodesIndexes)
            ]
        )
    }

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

    func createNodesSection(
        with nodes: [MeasuredNode],
        nodesIndexes: [String: Int]
    ) -> Section {
        Section(
            title: "Default Nodes".uppercased(),
            rows: nodes.map {
                .node(createNodeViewModel(for: $0, index: nodesIndexes[$0.node.url]!))
            }
        )
    }

    func createNodeViewModel(
        for measuredNode: MeasuredNode,
        index: Int
    ) -> Node {
        let connectionState: Node.ConnectionState = switch measuredNode.connectionState {
        case .connecting:
            .connecting(
                R.string.localizable.networkStatusConnecting(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).uppercased()
            )
        case let .connected(ping):
            switch ping {
            case 0 ..< 100:
                .connected(.low("\(ping)"))
            case 100 ..< 500:
                .connected(.medium("\(ping)"))
            default:
                .connected(.high("\(ping)"))
            }
        }

        return Node(
            index: index,
            name: measuredNode.node.name,
            url: measuredNode.node.url,
            connectionState: connectionState,
            selected: false
        )
    }
}
