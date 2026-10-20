import Foundation

enum NovaAuthBootstrapRoute: String {
    case registrationChallenge = "/v1/attestation/profile-3/challenges"
    case tokenChallenge = "/v1/attestation/profile-3/token-challenges"
    case registration = "/v1/attestation/profile-3/register"
    case token = "/v1/attestation/profile-3/tokens"

    var path: String { rawValue }

    var bodyLimit: Int {
        switch self {
        case .registrationChallenge, .tokenChallenge: return 1024
        case .registration: return 98304
        case .token: return 16384
        }
    }

    var timeout: TimeInterval {
        self == .registration ? 100 : 20
    }
}

enum NovaAuthRoute {
    static func validate(method: NovaAuthMethod, path: String, body: Data?, contentType: String?) throws {
        guard path.hasPrefix("/"), !path.hasPrefix("//"),
              !path.contains("//"), !path.contains("\\"), !path.contains("%"),
              !path.contains("?"), !path.contains("#"),
              !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
            throw NovaAuthError.invalidRequest
        }
        if method != .post {
            guard body == nil, contentType == nil else { throw NovaAuthError.invalidRequest }
        } else if let contentType {
            guard !contentType.isEmpty, contentType.utf8.allSatisfy({ (32 ... 126).contains($0) }) else {
                throw NovaAuthError.invalidRequest
            }
        }
    }
}
