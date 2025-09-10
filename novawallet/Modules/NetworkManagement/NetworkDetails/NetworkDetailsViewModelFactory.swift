import Foundation
import Foundation_iOS

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
        for chain: ChainModel,
        nodes: [ChainNodeModel],
        selectedNode: ChainNodeModel?,
        nodesIds: [String: UUID],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState],
        onTapEdit: @escaping (UUID) -> Void,
        onTapMore: @escaping (UUID) -> Void
    ) -> Details {
        let customNodes = nodes.filter { $0.source == .user }
        let remoteNodes = nodes.filter { $0.source == .remote }

        var sections: [Section] = [
            createSwitchesSection(for: chain),
            createAddNodeSection(
                with: customNodes,
                selectedNode: selectedNode,
                chain: chain,
                nodesIds: nodesIds,
                connectionStates: connectionStates,
                deletionAllowed: customNodes.count > 1 || !remoteNodes.isEmpty,
                onTapEdit: onTapEdit,
                onTapMore: onTapMore
            )
        ]

        if !remoteNodes.isEmpty {
            let defaultNodesSection = createNodesSection(
                with: remoteNodes,
                selectedNode: selectedNode,
                chain: chain,
                nodesIds: nodesIds,
                connectionStates: connectionStates
            )

            sections.append(defaultNodesSection)
        }

        return Details(
            customNetwork: chain.source == .user,
            networkViewModel: networkViewModelFactory.createViewModel(from: chain),
            sections: sections
        )
    }

    func createNodesSection(
        with nodes: [ChainNodeModel],
        selectedNode: ChainNodeModel?,
        chain: ChainModel,
        nodesIds: [String: UUID],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState]
    ) -> Section {
        Section(
            title: R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
            ).localizable.networkDetailsDefaultNodesSectionTitle().uppercased(),
            rows: createNodeViewModels(
                for: nodes,
                chain: chain,
                selectedNode: selectedNode,
                ids: nodesIds,
                connectionStates: connectionStates,
                deletionAllowed: false,
                onTapEdit: nil,
                onTapMore: nil
            )
        )
    }

    func createAddNodeSection(
        with nodes: [ChainNodeModel],
        selectedNode: ChainNodeModel?,
        chain: ChainModel,
        nodesIds: [String: UUID],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState],
        deletionAllowed: Bool,
        onTapEdit: @escaping (UUID) -> Void,
        onTapMore: @escaping (UUID) -> Void
    ) -> Section {
        var rows: [NetworkDetailsViewLayout.Row] = [
            .addCustomNode(
                .init(
                    title: R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.networkDetailsAddCustomNode(),
                    icon: nil
                )
            )
        ]

        let nodeRows = createNodeViewModels(
            for: nodes,
            chain: chain,
            selectedNode: selectedNode,
            ids: nodesIds,
            connectionStates: connectionStates,
            deletionAllowed: deletionAllowed,
            onTapEdit: onTapEdit,
            onTapMore: onTapMore
        )

        rows.append(contentsOf: nodeRows)

        return Section(
            title: R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
            ).localizable.networkDetailsCustomNodesSectionTitle().uppercased(),
            rows: rows
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
                            title: R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.networkDetailsEnableConnection(),
                            icon: nil
                        ),
                        selectable: network.syncMode.enabled(),
                        enabled: network.chainId != KnowChainId.polkadot
                    )
                ),
                .switcher(
                    .init(
                        underlyingViewModel: .init(
                            title: R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.networkDetailsAutoBalance(),
                            icon: nil
                        ),
                        selectable: network.connectionMode == .autoBalanced && network.syncMode.enabled(),
                        enabled: network.syncMode.enabled()
                    )
                )
            ]
        )
    }

    func createNodeViewModels(
        for nodes: [ChainNodeModel],
        chain: ChainModel,
        selectedNode: ChainNodeModel?,
        ids: [String: UUID],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState],
        deletionAllowed: Bool,
        onTapEdit: ((UUID) -> Void)?,
        onTapMore: ((UUID) -> Void)?
    ) -> [NetworkDetailsViewLayout.Row] {
        nodes.map {
            let selected = $0.url == selectedNode?.url

            return .node(
                createNodeViewModel(
                    for: $0,
                    selected: chain.syncMode.enabled() ? selected : false,
                    chain: chain,
                    ids: ids,
                    connectionStates: connectionStates,
                    deletionAllowed: deletionAllowed,
                    onTapEdit: onTapEdit,
                    onTapMore: onTapMore
                )
            )
        }
    }

    func createNodeViewModel(
        for node: ChainNodeModel,
        selected: Bool,
        chain: ChainModel,
        ids: [String: UUID],
        connectionStates: [String: NetworkDetailsPresenter.ConnectionState],
        deletionAllowed: Bool,
        onTapEdit: ((UUID) -> Void)?,
        onTapMore: ((UUID) -> Void)?
    ) -> Node {
        var connectionState: Node.ConnectionState = chain.syncMode.enabled()
            ? .connecting(
                R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.networkStatusConnecting().uppercased()
            )
            : .disconnected

        if let nodeConnectionState = connectionStates[node.url] {
            connectionState = switch nodeConnectionState {
            case .connecting:
                .connecting(
                    R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.networkStatusConnecting().uppercased()
                )
            case .disconnected:
                .disconnected
            case let .pinged(ping):
                createConnectionState(for: ping)
            default:
                .unknown(
                    R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.commonUnknown().uppercased()
                )
            }
        }

        let accessory: Node.Accessory = if node.source == .user, !deletionAllowed {
            .edit(R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.commonEdit()
            )
        } else if node.source == .user, deletionAllowed {
            .more
        } else {
            .none
        }

        return Node(
            id: ids[node.url]!,
            name: node.name,
            url: trimUrlPath(urlString: node.url),
            connectionState: connectionState,
            selected: selected,
            dimmed: chain.connectionMode == .autoBalanced,
            custom: node.source == .user,
            accessory: accessory,
            onTapMore: onTapMore,
            onTapEdit: onTapEdit
        )
    }

    func createConnectionState(for ping: Int) -> Node.ConnectionState {
        let string = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages
        ).localizable.networkDetailsPingMilliseconds(ping).uppercased()

        return switch ping {
        case 0 ..< 100:
            .pinged(.low(string))
        case 100 ..< 500:
            .pinged(.medium(string))
        default:
            .pinged(.high(string))
        }
    }

    func trimUrlPath(urlString: String) -> String {
        var urlComponents = URLComponents(
            url: URL(string: urlString)!,
            resolvingAgainstBaseURL: false
        )
        urlComponents?.path = ""
        urlComponents?.queryItems = []

        let trimmedUrlString = urlComponents?
            .url?
            .absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "?"))

        return trimmedUrlString ?? urlString
    }
}
