import Foundation
import Operation_iOS

struct AppAttestBrowserSettings: Codable {
    let baseURL: String
    let keyId: String
    let isAttested: Bool
}

extension AppAttestBrowserSettings: Identifiable {
    var identifier: String { baseURL }
}
