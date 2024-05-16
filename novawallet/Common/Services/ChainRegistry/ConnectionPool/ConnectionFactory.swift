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

    let tlsSupportProvider = ConnectionTLSSupportProvider()

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
        let urlModels = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.wss)
        let urls = urlModels.map(\.url)

        tlsSupportProvider.add(support: urlModels)

        let healthCheckMethod: HealthCheckMethod = chain.hasSubstrateRuntime ? .substrate : .websocketPingPong
        let nodeSwitcher = JSONRRPCodeNodeSwitcher(codes: ConnectionNodeSwitchCode.allCodes)

        guard
            let connection = WebSocketEngine(
                urls: urls,
                connectionFactory: ConnectionTransportFactory(tlsSupportProvider: tlsSupportProvider),
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
        let newUrlModels = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.wss)
        let newUrls = newUrlModels.map(\.url)

        tlsSupportProvider.add(support: newUrlModels)

        if Set(connection.urls) != Set(newUrls) {
            connection.changeUrls(newUrls)
        }
    }

    func createOneShotConnection(for chain: ChainModel) throws -> OneShotConnection {
        let urlModels = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.https)
        let urls = urlModels.map(\.url)

        tlsSupportProvider.add(support: urlModels)

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
        let newUrlModels = extractNodeUrls(from: chain, schema: ConnectionNodeSchema.https)
        let newUrls = newUrlModels.map(\.url)

        tlsSupportProvider.add(support: newUrlModels)

        if Set(connection.urls) != Set(newUrls) {
            connection.changeUrls(newUrls)
        }
    }

    private func extractNodeUrls(from chain: ChainModel, schema: String) -> [ConnectionTLSSupport] {
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

            let optUrl = try? builder.buildBy { apiKeyType in
                guard let apiKey = ConnectionApiKeys.getKey(by: apiKeyType) else {
                    throw CommonError.undefined
                }

                return apiKey
            }

            guard let url = optUrl else {
                return nil
            }

            return ConnectionTLSSupport(url: url, supportsTLS12: node.supportsTls12)
        }
    }
}
