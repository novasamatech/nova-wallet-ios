import Foundation
import SubstrateSdk

struct AppAttestMessage: Codable {
    let identifier: String
    let messageType: AppAttestMessageType
    let request: JSON?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case messageType
        case request
        case url
    }
}

enum AppAttestMessageType: String, CaseIterable, Codable {
    case requestIntegrityCheck = "app.requestIntegrityCheck"
}
