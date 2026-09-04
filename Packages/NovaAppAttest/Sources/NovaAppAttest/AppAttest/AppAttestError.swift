import Foundation

enum AppAttestError: Error {
    case invalidResponse
    case networkError(Error)
    case serverError(Int)
    case noData
    case attestationFailed
}

extension AppAttestError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        case let .serverError(code):
            return "Server error with status code: \(code)"
        case .noData:
            return "No data received from server"
        case .attestationFailed:
            return "Attestation process failed"
        }
    }
}
