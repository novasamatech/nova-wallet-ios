import Foundation

enum DeviceCheckResult {
    case supported(Data)
    case unsupported
}

enum DeviceCheckError: Error {
    case invalidData
}
