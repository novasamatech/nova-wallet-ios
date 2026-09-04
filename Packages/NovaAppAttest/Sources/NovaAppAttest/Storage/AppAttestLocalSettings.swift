import Foundation
import Operation_iOS

public struct AppAttestKeySettings: Codable, Equatable {
    public let identifier: String
    public let keyId: String
    public let isAttested: Bool

    public init(identifier: String, keyId: String, isAttested: Bool) {
        self.identifier = identifier
        self.keyId = keyId
        self.isAttested = isAttested
    }
}

extension AppAttestKeySettings: Identifiable {}
