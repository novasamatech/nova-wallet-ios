import Foundation

enum DAppAttestError: Error {
    case serverError(DAppAssertionCallFactory)
    case unsupportedDevice
}
