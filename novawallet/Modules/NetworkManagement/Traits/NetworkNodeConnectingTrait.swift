import Foundation
import SubstrateSdk

protocol NetworkNodeConnectingTrait: AnyObject, WebSocketEngineDelegate {
    var chainRegistry: ChainRegistryProtocol { get }
    var connectionFactory: ConnectionFactoryProtocol { get }
}

extension NetworkNodeConnectingTrait {
    func connect(
        to node: ChainNodeModel,
        replacing existingNode: ChainNodeModel?,
        chain: ChainNodeConnectable,
        urlPredicate: NSPredicate
    ) throws -> ChainConnection {
        if let existingNode = findExistingNode(with: node.url, ignoring: existingNode) {
            throw NetworkNodeConnectingError.alreadyExists(
                node: existingNode.node,
                chain: existingNode.chain
            )
        }

        guard urlPredicate.evaluate(with: node.url) else {
            throw NetworkNodeConnectingError.wrongFormat
        }

        return try connectionFactory.createConnection(
            for: node,
            chain: chain,
            delegate: self
        )
    }

    func findExistingNode(
        with url: String,
        ignoring replacedNode: ChainNodeModel? = nil
    ) -> (node: ChainNodeModel, chain: ChainModel)? {
        guard let chainIds = chainRegistry.availableChainIds else {
            return nil
        }

        let predicate: (ChainNodeModel) -> Bool = replacedNode == nil
            ? { $0.url == url }
            : { $0.url == url && $0.url != replacedNode?.url }

        return chainIds
            .compactMap { chainId -> (node: ChainNodeModel, chain: ChainModel)? in
                guard
                    let chain = chainRegistry.getChain(for: chainId),
                    let existingNode = chain.nodes.first(where: predicate)
                else { return nil }

                return (node: existingNode, chain: chain)
            }
            .first
    }
}

// MARK: Errors

enum NetworkNodeConnectingError: Error {
    case alreadyExists(node: ChainNodeModel, chain: ChainModel)
    case unableToConnect(networkName: String)
    case wrongFormat
}

extension NetworkNodeConnectingError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String

        switch self {
        case let .alreadyExists(node, _):
            title = R.string.localizable.networkNodeAddAlertAlreadyExistsTitle(
                preferredLanguages: locale?.rLanguages
            )
            message = R.string.localizable.networkNodeAddAlertAlreadyExistsMessage(
                node.name,
                preferredLanguages: locale?.rLanguages
            )
        case .wrongFormat:
            title = R.string.localizable.networkNodeAddAlertNodeErrorTitle(
                preferredLanguages: locale?.rLanguages
            )
            message = R.string.localizable.networkNodeAddAlertNodeErrorMessageWss(
                preferredLanguages: locale?.rLanguages
            )
        case let .unableToConnect(networkName):
            title = R.string.localizable.networkNodeAddAlertWrongNetworkTitle(
                preferredLanguages: locale?.rLanguages
            )
            message = R.string.localizable.networkNodeAddAlertWrongNetworkMessage(
                networkName,
                networkName,
                preferredLanguages: locale?.rLanguages
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
