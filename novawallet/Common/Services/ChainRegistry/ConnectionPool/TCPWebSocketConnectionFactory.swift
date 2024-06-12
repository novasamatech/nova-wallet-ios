import Foundation
import SubstrateSdk
import Starscream

final class TCPWebSocketConnectionFactory {}

extension TCPWebSocketConnectionFactory: WebSocketConnectionFactoryProtocol {
    func createConnection(
        for url: URL,
        processingQueue: DispatchQueue,
        connectionTimeout: TimeInterval
    ) -> WebSocketConnectionProtocol {
        let request = URLRequest(url: url, timeoutInterval: connectionTimeout)

        let engine = WSEngine(
            transport: TCPTransport(),
            certPinner: FoundationSecurity(),
            compressionHandler: nil
        )

        let connection = WebSocket(request: request, engine: engine)
        connection.callbackQueue = processingQueue

        return connection
    }
}
