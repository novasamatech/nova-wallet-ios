import Foundation

struct PolkadotExtensionSignerResult: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case signature
    }

    let identifier: UInt
    let signature: String
}
