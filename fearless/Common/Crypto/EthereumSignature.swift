import Foundation
import FearlessUtils

struct EthereumSignature: Codable {
    enum CodingKeys: String, CodingKey {
        case rPart = "r"
        case sPart = "s"
        case vPart = "v"
    }

    let rPart: H256
    let sPart: H256
    @StringCodable var vPart: UInt8

    init?(rawValue: Data) {
        guard rawValue.count == 65 else {
            return nil
        }

        rPart = H256(value: rawValue[0 ..< 32])
        sPart = H256(value: rawValue[32 ..< 64])
        vPart = rawValue[64]
    }
}
