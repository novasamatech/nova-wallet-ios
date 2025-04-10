import Foundation
import SubstrateSdk
import BigInt

struct RuntimeDispatchInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case fee = "partialFee"
        case weight
    }

    let fee: String
    @Substrate.WeightDecodable var weight: Substrate.WeightV2

    init(fee: String, weight: Substrate.WeightV2) {
        self.fee = fee
        _weight = .init(wrappedValue: weight)
    }
}
