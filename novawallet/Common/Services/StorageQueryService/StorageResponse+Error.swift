import Foundation

enum StorageResponseError: Error {
    case unexpectedEmptyValue
}

extension StorageResponse {
    func ensureValue() throws -> T {
        guard let value else {
            throw StorageResponseError.unexpectedEmptyValue
        }

        return value
    }
}
