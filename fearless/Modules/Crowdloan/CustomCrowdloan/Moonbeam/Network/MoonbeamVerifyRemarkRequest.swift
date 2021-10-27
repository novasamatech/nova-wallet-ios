import Foundation

struct MoonbeamVerifyRemarkRequest {
    let address: String
    let extrinsicHash: String
    let blockHash: String
}

extension MoonbeamVerifyRemarkRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case address
        case extrinsicHash = "extrinsic_hash"
        case blockHash = "block_hash"
    }
}
