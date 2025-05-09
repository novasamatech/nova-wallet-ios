import Foundation

enum AuthCredentialsError: Error {
    case brokenCredentialParams
}

enum AuthCredentials {
    static func basic(for userId: String, password: String) throws -> String {
        let toEncode = [userId, password].joined(separator: ":")
        guard let credentials = toEncode.data(using: .utf8)?.base64EncodedString() else {
            throw AuthCredentialsError.brokenCredentialParams
        }

        return "Basic \(credentials)"
    }
}
