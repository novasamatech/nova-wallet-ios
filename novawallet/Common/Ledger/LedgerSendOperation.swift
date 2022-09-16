import Foundation
import RobinHood

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

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        guard let message = message else {
            result = .failure(LedgerSendOperationError.noMessage)
            return
        }

        do {
            let mutex = DispatchSemaphore(value: 0)

            var receivedResult: Result<Data, Error>?

            try connection.send(message: message, deviceId: deviceId) { result in
                receivedResult = result

                mutex.signal()
            }

            _ = mutex.wait(timeout: .distantFuture)

            result = receivedResult
        } catch {
            result = .failure(error)
        }
    }
}
