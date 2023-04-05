import Foundation
import SubstrateSdk
import SoraFoundation

protocol ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel, delegate: WebSocketEngineDelegate?) throws -> ChainConnection
    func updateConnection(_ connection: ChainConnection, chain: ChainModel)
}

final class ConnectionFactory {
    let logger: SDKLoggerProtocol

    init(logger: SDKLoggerProtocol) {
        self.logger = logger
    }
}

enum ConnectionFactoryError: Error {
    case noNodes
}

extension ConnectionFactory: ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel, delegate: WebSocketEngineDelegate?) throws -> ChainConnection {
        let urls = extractNodeUrls(from: chain)

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
        let newUrls = extractNodeUrls(from: chain)

        if Set(connection.urls) != Set(newUrls) {
            connection.changeUrls(newUrls)
        }
    }

    private func extractNodeUrls(from chain: ChainModel) -> [URL] {
        let nodes: [ChainNodeModel]

        switch chain.nodeSwitchStrategy {
        case .roundRobin:
            nodes = chain.nodes.sorted(by: { $0.order < $1.order })
        case .uniform:
            nodes = chain.nodes.shuffled()
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
