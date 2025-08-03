import Foundation

enum AppAttestError: Error {
    case invalidURL
    case invalidResponse
    case invalidChallengeFormat
    case invalidChallengeLength
    case networkError(Error)
    case serverError(Int)
    case noData
    case attestationFailed
}

extension AppAttestError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidChallengeFormat:
            return "Invalid challenge format received"
        case .invalidChallengeLength:
            return "Challenge must be 16 bytes"
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
