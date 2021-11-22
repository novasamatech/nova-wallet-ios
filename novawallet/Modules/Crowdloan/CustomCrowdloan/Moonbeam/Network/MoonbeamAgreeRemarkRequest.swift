import Foundation

struct MoonbeamAgreeRemarkRequest {
    let address: AccountAddress
    let signedMessage: String
}

extension MoonbeamAgreeRemarkRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case address
        case signedMessage = "signed-message"
    }
}
