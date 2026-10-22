import Foundation

public enum NovaAuthEnvironment: String, Codable { case development, production }

public struct NovaAuthAppIdentity: Equatable {
    public let appID: String
    public let environment: NovaAuthEnvironment
    public let version: String

    public init(appID: String, environment: NovaAuthEnvironment, version: String) throws {
        let parts = appID.split(separator: ".", omittingEmptySubsequences: false)
        guard (3 ... 120).contains(appID.utf8.count), parts.count >= 2,
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy {
                  (65 ... 90).contains($0) || (97 ... 122).contains($0) || (48 ... 57).contains($0) || $0 == 45
              } }),
              (1 ... 64).contains(version.utf8.count),
              version.utf8.allSatisfy({ (33 ... 126).contains($0) }) else { throw NovaAuthError.invalidConfiguration }
        self.appID = appID
        self.environment = environment
        self.version = version
    }
}

public struct NovaAuthContext: Hashable, Codable {
    public let origin: NovaAuthOrigin
    public let generation: UInt64

    public init(origin: NovaAuthOrigin, generation: UInt64) {
        self.origin = origin
        self.generation = generation
    }
}
