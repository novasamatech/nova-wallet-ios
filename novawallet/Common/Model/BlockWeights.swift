import Foundation
import SubstrateSdk
import BigInt

enum BlockchainWeight {
    typealias WeightV1 = StringScaleMapper<UInt64>

    struct WeightV1P5: Decodable {
        @StringCodable var refTime: UInt64
    }

    struct WeightV2: Codable {
        @StringCodable var refTime: BigUInt
        @StringCodable var proofSize: UInt64
    }
}

struct BlockWeights: Decodable {
    enum CodingKeys: String, CodingKey {
        case maxBlock
    }

    let maxBlock: UInt64

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let weight = try? container.decode(BlockchainWeight.WeightV1P5.self, forKey: .maxBlock) {
            maxBlock = weight.refTime
        } else {
            maxBlock = try container.decode(BlockchainWeight.WeightV1.self, forKey: .maxBlock).value
        }
    }
}
