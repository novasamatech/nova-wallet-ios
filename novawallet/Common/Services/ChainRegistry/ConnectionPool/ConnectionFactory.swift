import Foundation
import SubstrateSdk
import SoraFoundation

protocol ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel, delegate: WebSocketEngineDelegate?) throws -> ChainConnection
    func createOneShotConnection(for chain: ChainModel) throws -> OneShotConnection
    func updateConnection(_ connection: ChainConnection, chain: ChainModel)
    func updateOneShotConnection(_ connection: OneShotConnection, chain: ChainModel)
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
}

extension ConnectionFactory: ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel, delegate: WebSocketEngineDelegate?) throws -> ChainConnection {
        let urls = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.wss)

        let healthCheckMethod: HealthCheckMethod = chain.hasSubstrateRuntime ? .substrate : .websocketPingPong
        let nodeSwitcher = JSONRRPCodeNodeSwitcher(codes: ConnectionNodeSwitchCode.allCodes)

        guard
            let connection = WebSocketEngine(
                urls: urls,
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

    func updateConnection(_ connection: ChainConnection, chain: ChainModel) {
        let newUrls = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.wss)

        if Set(connection.urls) != Set(newUrls) {
            connection.changeUrls(newUrls)
        }
    }

    func createOneShotConnection(for chain: ChainModel) throws -> OneShotConnection {
        let urls = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.https)

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

    func updateOneShotConnection(_ connection: OneShotConnection, chain: ChainModel) {
        let newUrls = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.https)

        if Set(connection.urls) != Set(newUrls) {
            connection.changeUrls(newUrls)
        }
    }

    private func extractNodeUrls(from chain: ChainModel, schema: String) -> [URL] {
        let filteredNodes = chain.nodes.filter { $0.url.hasPrefix(schema) }

        let nodes: [ChainNodeModel]

        switch chain.nodeSwitchStrategy {
        case .roundRobin:
            nodes = filteredNodes.sorted(by: { $0.order < $1.order })
        case .uniform:
            nodes = filteredNodes.shuffled()
        }

        return nodes.compactMap { node in
            let builder = URLBuilder(urlTemplate: node.url)

            return try? builder.buildBy { apiKeyType in
                guard let apiKey = ConnectionApiKeys.getKey(by: apiKeyType) else {
                    throw CommonError.undefined
                }

                return apiKey
            }
        }
    }
}
