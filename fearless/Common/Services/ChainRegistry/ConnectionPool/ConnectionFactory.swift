import Foundation
import SubstrateSdk

typealias ChainConnection = JSONRPCEngine & ConnectionAutobalancing & ConnectionStateReporting

protocol ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel, delegate: WebSocketEngineDelegate?) throws -> ChainConnection
}

final class ConnectionFactory {
    let logger: SDKLoggerProtocol

    init(logger: SDKLoggerProtocol) {
        self.logger = logger
    }
}

extension ConnectionFactory: ConnectionFactoryProtocol {
    func createConnection(for chain: ChainModel, delegate: WebSocketEngineDelegate?) throws -> ChainConnection {
        let urls = chain.nodes.sorted(by: { $0.order < $1.order }).map(\.url)

        guard let connection = WebSocketEngine(urls: urls, name: chain.name, logger: logger) else {
            throw JSONRPCEngineError.unknownError
        }

        connection.delegate = delegate
        return connection
    }
}
