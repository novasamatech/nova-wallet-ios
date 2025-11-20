import Foundation
import SubstrateSdk
import Foundation_iOS

protocol ConnectionFactoryProtocol {
    func createConnection(
        for chain: ChainNodeConnectable,
        delegate: WebSocketEngineDelegate?
    ) throws -> ChainConnection

    func createConnection(
        for node: ChainNodeModel,
        chain: ChainNodeConnectable,
        delegate: WebSocketEngineDelegate?
    ) throws -> ChainConnection

    func updateConnection(
        _ connection: ChainConnection,
        chain: ChainNodeConnectable
    )

    func updateOneShotConnection(
        _ connection: OneShotConnection,
        chain: ChainNodeConnectable
    )

    func createOneShotConnection(for chain: ChainNodeConnectable) throws -> OneShotConnection
}

final class ConnectionFactory {
    let logger: SDKLoggerProtocol
    let operationQueue: OperationQueue

    init(logger: SDKLoggerProtocol, operationQueue: OperationQueue) {
        self.logger = logger
        self.operationQueue = operationQueue
    }
}

enum ConnectionFactoryError: Error {
    case noNodes
    case invalidNode
}

extension ConnectionFactory: ConnectionFactoryProtocol {
    func createConnection(
        for chain: ChainNodeConnectable,
        delegate: WebSocketEngineDelegate?
    ) throws -> ChainConnection {
        let urlModels = extractNodeUrls(
            from: chain,
            schemaPredicate: .ws
        )

        return try createConnection(
            urlModels: urlModels,
            for: chain,
            delegate: delegate
        )
    }

    func createConnection(
        for node: ChainNodeModel,
        chain: ChainNodeConnectable,
        delegate: WebSocketEngineDelegate?
    ) throws -> ChainConnection {
        guard let urlModel = nodeUrl(from: node) else {
            throw ConnectionFactoryError.invalidNode
        }

        return try createConnection(
            urlModels: [urlModel],
            for: chain,
            delegate: delegate
        )
    }

    func updateConnection(_ connection: ChainConnection, chain: ChainNodeConnectable) {
        let newUrlModels = extractNodeUrls(
            from: chain,
            schemaPredicate: .ws
        )
        let newUrls = newUrlModels.map(\.url)

        if Set(connection.urls) != Set(newUrls) {
            connection.changeUrls(newUrls)
        }
    }

    func createOneShotConnection(for chain: ChainNodeConnectable) throws -> OneShotConnection {
        let urls = extractNodeUrls(
            from: chain,
            schemaPredicate: .urlPredicate
        ).map(\.url)

        let nodeSwitcher = JSONRRPCodeNodeSwitcher(codes: ConnectionNodeSwitchCode.allCodes)

        guard
            let connection = HTTPEngine(
                urls: urls,
                operationQueue: operationQueue,
                customNodeSwitcher: nodeSwitcher,
                timeout: TimeInterval(JSONRPCTimeout.withNodeSwitch),
                name: chain.name,
                logger: logger
            ) else {
            throw ConnectionFactoryError.noNodes
        }

        return connection
    }

    func updateOneShotConnection(
        _ connection: OneShotConnection,
        chain: ChainNodeConnectable
    ) {
        let newUrls = extractNodeUrls(
            from: chain,
            schemaPredicate: .urlPredicate
        ).map(\.url)

        if Set(connection.urls) != Set(newUrls) {
            connection.changeUrls(newUrls)
        }
    }

    private func createConnection(
        urlModels: [ConnectionCreationParams],
        for chain: ChainNodeConnectable,
        delegate: WebSocketEngineDelegate?
    ) throws -> ChainConnection {
        let healthCheckMethod: HealthCheckMethod = chain.hasSubstrateRuntime ? .substrate : .websocketPingPong
        let nodeSwitcher = JSONRRPCodeNodeSwitcher(codes: ConnectionNodeSwitchCode.allCodes)

        let urls = urlModels.map(\.url)

        guard
            let connection = WebSocketEngine(
                urls: urls,
                connectionFactory: ConnectionTransportFactory(),
                customNodeSwitcher: nodeSwitcher,
                healthCheckMethod: healthCheckMethod,
                name: chain.name,
                logger: logger
            ) else {
            throw ConnectionFactoryError.noNodes
        }

        connection.delegate = delegate
        return connection
    }

    private func nodeUrl(from node: ChainNodeModel) -> ConnectionCreationParams? {
        guard let url = node.getUrl() else {
            return nil
        }

        return ConnectionCreationParams(url: url)
    }

    private func extractNodeUrls(
        from chain: ChainNodeConnectable,
        schemaPredicate: NSPredicate
    ) -> [ConnectionCreationParams] {
        let filteredNodes = if case let .manual(selectedNode) = chain.connectionMode {
            schemaPredicate.evaluate(with: selectedNode.url)
                ? Set([selectedNode])
                : Set()
        } else {
            chain.nodes.filter { schemaPredicate.evaluate(with: $0.url) }
        }

        let nodes: [ChainNodeModel]

        switch chain.nodeSwitchStrategy {
        case .roundRobin:
            nodes = filteredNodes.sorted(by: { $0.order < $1.order })
        case .uniform:
            nodes = filteredNodes.shuffled()
        }

        return nodes.compactMap { nodeUrl(from: $0) }
    }
}
