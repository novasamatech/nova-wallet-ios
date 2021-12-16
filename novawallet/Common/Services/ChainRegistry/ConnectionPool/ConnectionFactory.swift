import Foundation
import SubstrateSdk

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

extension ConnectionFactory: ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel, delegate: WebSocketEngineDelegate?) throws -> ChainConnection {
        let urls = extractNodeUrls(from: chain)

        guard let connection = WebSocketEngine(urls: urls, name: chain.name, logger: logger) else {
            throw JSONRPCEngineError.unknownError
        }

        connection.delegate = delegate
        return connection
    }

    func updateConnection(_ connection: ChainConnection, chain: ChainModel) {
        let newUrls = extractNodeUrls(from: chain)

        if connection.urls != newUrls {
            connection.changeUrls(newUrls)
        }
    }

    private func extractNodeUrls(from chain: ChainModel) -> [URL] {
        chain.nodes.sorted(by: { $0.order < $1.order }).map(\.url)
    }
}
