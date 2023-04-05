import Foundation
import SubstrateSdk
import SoraFoundation

protocol ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel, delegate: WebSocketEngineDelegate?) throws -> ChainConnection
    func updateConnection(_ connection: ChainConnection, chain: ChainModel)
    func createOnShotConnection(for chain: ChainModel) -> JSONRPCEngine?
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
        let newUrls = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.https)

        if Set(connection.urls) != Set(newUrls) {
            connection.changeUrls(newUrls)
        }
    }

    func createOnShotConnection(for chain: ChainModel) -> JSONRPCEngine? {
        let urls = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.https)

        guard !urls.isEmpty else {
            return nil
        }

        let nodeSwitcher = JSONRRPCodeNodeSwitcher(codes: ConnectionNodeSwitchCode.allCodes)

        return HTTPEngine(
            urls: urls,
            operationQueue: operationQueue,
            customNodeSwitcher: nodeSwitcher,
            timeout: 15,
            name: chain.name,
            logger: logger
        )
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
