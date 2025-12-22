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
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.networkNodeAddAlertAlreadyExistsTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.networkNodeAddAlertAlreadyExistsMessage(
                node.name
            )
        case .wrongFormat:
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.networkNodeAddAlertNodeErrorTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.networkNodeAddAlertNodeErrorMessageWss()
        case let .unableToConnect(networkName):
            title = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.networkNodeAddAlertWrongNetworkTitle()
            message = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.networkNodeAddAlertWrongNetworkMessage(
                networkName,
                networkName
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
