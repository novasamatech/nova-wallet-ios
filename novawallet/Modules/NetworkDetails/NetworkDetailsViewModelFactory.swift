import SoraFoundation

class NetworkDetailsViewModelFactory {
    typealias Details = NetworkDetailsViewLayout.Model
    typealias Section = NetworkDetailsViewLayout.Section
    typealias Node = NetworkDetailsViewLayout.NodeModel

    private let localizationManager: LocalizationManagerProtocol

    private let networkViewModelFactory: NetworkViewModelFactoryProtocol

    init(
        localizationManager: LocalizationManagerProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol
    ) {
        self.localizationManager = localizationManager
        self.networkViewModelFactory = networkViewModelFactory
    }

    func createViewModel(
        for network: ChainModel,
        nodes: [ChainNodeModel],
        selectedNode: ChainNodeModel?,
        nodesIndexes: [String: Int],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState]
    ) -> Details {
        Details(
            networkViewModel: networkViewModelFactory.createViewModel(from: network),
            sections: [
                createSwitchesSection(for: network),
                createAddNodeSection(),
                createNodesSection(
                    with: nodes,
                    selectedNode: selectedNode,
                    chain: network,
                    nodesIndexes: nodesIndexes,
                    connectionStates: connectionStates
                )
            ]
        )
    }

    func createNodesSection(
        with nodes: [ChainNodeModel],
        selectedNode: ChainNodeModel?,
        chain: ChainModel,
        nodesIndexes: [String: Int],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState]
    ) -> Section {
        Section(
            title: R.string.localizable.networkDetailsDefaultNodesSectionTitle(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ).uppercased(),
            rows: nodes.map {
                let selected = $0.url == selectedNode?.url

                return .node(
                    createNodeViewModel(
                        for: $0,
                        selected: chain.syncMode.enabled() ? selected : false,
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
                        underlyingViewModel: .init(
                            title: R.string.localizable.networkDetailsEnableConnection(
                                preferredLanguages: localizationManager.selectedLocale.rLanguages
                            ),
                            icon: nil
                        ),
                        selectable: network.syncMode.enabled(),
                        enabled: network.chainId != KnowChainId.polkadot
                    )
                ),
                .switcher(
                    .init(
                        underlyingViewModel: .init(
                            title: R.string.localizable.networkDetailsAutoBalance(
                                preferredLanguages: localizationManager.selectedLocale.rLanguages
                            ),
                            icon: nil
                        ),
                        selectable: network.connectionMode == .autoBalanced && network.syncMode.enabled(),
                        enabled: network.syncMode.enabled()
                    )
                )
            ]
        )
    }

    func createAddNodeSection() -> Section {
        Section(
            title: R.string.localizable.networkDetailsCustomNodesSectionTitle(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            ).uppercased(),
            rows: [
                .addCustomNode(
                    .init(
                        title: R.string.localizable.networkDetailsAddCustomNode(
                            preferredLanguages: localizationManager.selectedLocale.rLanguages
                        ),
                        icon: nil
                    )
                )
            ]
        )
    }

    func createNodeViewModel(
        for node: ChainNodeModel,
        selected: Bool,
        chain: ChainModel,
        indexes: [String: Int],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState]
    ) -> Node {
        var connectionState: Node.ConnectionState = chain.syncMode.enabled()
            ? .connecting(
                R.string.localizable.networkStatusConnecting(
                    preferredLanguages: localizationManager.selectedLocale.rLanguages
                ).uppercased()
            )
            : .disconnected

        if let nodeConnectionState = connectionStates[node.url] {
            connectionState = switch nodeConnectionState {
            case .connecting:
                .connecting(
                    R.string.localizable.networkStatusConnecting(
                        preferredLanguages: localizationManager.selectedLocale.rLanguages
                    ).uppercased()
                )
            case .disconnected:
                .disconnected
            case let .pinged(ping):
                createConnectionState(for: ping)
            default:
                .unknown(
                    R.string.localizable.commonUnknown(
                        preferredLanguages: localizationManager.selectedLocale.rLanguages
                    ).uppercased()
                )
            }
        }

        return Node(
            index: indexes[node.url]!,
            name: node.name,
            url: node.url,
            connectionState: connectionState,
            selected: selected,
            dimmed: chain.connectionMode == .autoBalanced
        )
    }

    func createConnectionState(for ping: Int) -> Node.ConnectionState {
        let string = R.string.localizable.networkDetailsPingMilliseconds(
            ping,
            preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).uppercased()

        return switch ping {
        case 0 ..< 100:
            .pinged(.low(string))
        case 100 ..< 500:
            .pinged(.medium(string))
        default:
            .pinged(.high(string))
        }
    }
}
