import Foundation

struct MoonbeamAgreeRemarkRequest {
    let address: AccountAddress
    let signedMessage: String
}

extension MoonbeamAgreeRemarkRequest: Encodable {
    private enum CodingKeys: String, CodingKey {
        case address
        case signedMessage = "signed-message"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(address, forKey: .address)
        try container.encode(signedMessage, forKey: .signedMessage)
    }
}
