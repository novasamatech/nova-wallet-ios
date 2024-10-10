import Foundation

struct PolkadotExtensionSignerResult: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case signature
        case signedTransaction
    }

    let identifier: UInt
    let signature: String
    let signedTransaction: String?
}
