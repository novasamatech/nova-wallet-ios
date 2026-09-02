import Foundation
import Operation_iOS

struct AppAttestKeySettings: Codable, Equatable {
    let identifier: String
    let keyId: String
    let isAttested: Bool
}

extension AppAttestKeySettings: Identifiable {}
