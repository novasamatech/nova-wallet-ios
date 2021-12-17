import Foundation

struct PolkadotExtensionSignerResult: Decodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case signature
    }

    let identifier: UInt
    let signature: String
}
