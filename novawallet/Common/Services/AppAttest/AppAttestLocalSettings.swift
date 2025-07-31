import Foundation
import Operation_iOS

struct AppAttestBrowserLocalSettings: Codable {
    let baseURL: String
    let keyId: String
    let isAttested: Bool
}

extension AppAttestBrowserLocalSettings: Identifiable {
    var identifier: String { baseURL }
}
