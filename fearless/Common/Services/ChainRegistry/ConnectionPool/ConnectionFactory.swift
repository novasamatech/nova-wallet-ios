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
        guard let url = chain.nodes.sorted(by: { $0.order < $1.order }).first?.url else {
            throw JSONRPCEngineError.unknownError
        }

        let connection = WebSocketEngine(url: url, logger: logger)
        connection.delegate = delegate
        return connection
    }
}
