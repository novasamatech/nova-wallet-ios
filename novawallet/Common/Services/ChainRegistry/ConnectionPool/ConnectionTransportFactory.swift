import Foundation
import SubstrateSdk
import Starscream

final class ConnectionTransportFactory {}

extension ConnectionTransportFactory: WebSocketConnectionFactoryProtocol {
    public func createConnection(
        for url: URL,
        processingQueue: DispatchQueue,
        connectionTimeout: TimeInterval
    ) -> WebSocketConnectionProtocol {
        let request = URLRequest(url: url, timeoutInterval: connectionTimeout)

        let transport = TCPTransport()

        let engine = WSEngine(
            transport: transport,
            certPinner: FoundationSecurity(),
            compressionHandler: nil
        )

        let connection = WebSocket(request: request, engine: engine)
        connection.callbackQueue = processingQueue

        return connection
    }
}
