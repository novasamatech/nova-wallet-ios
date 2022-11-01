import Foundation
import SubstrateSdk

enum BlockchainWeight {
    typealias WeightV1 = StringScaleMapper<UInt64>

    struct WeightV2: Decodable {
        @StringCodable var refTime: UInt64
    }
}

struct BlockWeights: Decodable {
    enum CodingKeys: String, CodingKey {
        case maxBlock
    }

    let maxBlock: UInt64

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let weight = try? container.decode(BlockchainWeight.WeightV2.self, forKey: .maxBlock) {
            maxBlock = weight.refTime
        } else {
            maxBlock = try container.decode(BlockchainWeight.WeightV1.self, forKey: .maxBlock).value
        }
    }
}
