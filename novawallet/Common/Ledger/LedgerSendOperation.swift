import Foundation
import Operation_iOS

enum LedgerSendOperationError: Error {
    case noMessage
}

final class LedgerSendOperation: BaseOperation<Data> {
    let connection: LedgerConnectionManagerProtocol
    let deviceId: UUID
    var message: Data?

    public init(connection: LedgerConnectionManagerProtocol, deviceId: UUID, message: Data? = nil) {
        self.connection = connection
        self.deviceId = deviceId
        self.message = message
    }

    override func performAsync(_ callback: @escaping (Result<Data, Error>) -> Void) throws {
        guard let message = message else {
            callback(.failure(LedgerSendOperationError.noMessage))
            return
        }

        try connection.send(message: message, deviceId: deviceId) { result in
            callback(result)
        }
    }
}
