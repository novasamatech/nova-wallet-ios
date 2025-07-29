import Foundation
import Operation_iOS

struct AppAttestLocalSettings: Codable {
    static let persistentId = "appattest.local.settings"

    let keyId: String
    let isAttested: Bool
}

extension AppAttestLocalSettings: Identifiable {
    var identifier: String { Self.persistentId }
}
