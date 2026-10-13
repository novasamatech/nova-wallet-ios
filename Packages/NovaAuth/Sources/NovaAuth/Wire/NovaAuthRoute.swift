import Foundation

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
