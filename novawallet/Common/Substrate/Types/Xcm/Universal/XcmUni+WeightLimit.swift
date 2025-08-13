import Foundation
import BigInt

extension XcmUni {
    typealias WeightLimit = Xcm.WeightLimit<Substrate.WeightV2>
}

extension XcmUni.WeightLimit: DecodableWithConfiguration {
    typealias DecodingConfiguration = Xcm.Version

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        switch configuration {
        case .V0, .V1, .V2:
            let v1Limit = try Xcm.WeightLimit<Substrate.WeightV1>(from: decoder)
            self.init(v1Limit: v1Limit)
        case .V3, .V4, .V5:
            try self.init(from: decoder)
        }
    }
}

extension XcmUni.WeightLimit: EncodableWithConfiguration {
    typealias EncodingConfiguration = Xcm.Version

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        switch configuration {
        case .V0, .V1, .V2:
            let newLimit = map { model in
                let weight = model.refTime > BigUInt(UInt64.max) ? UInt64.max : UInt64(model.refTime)
                return Substrate.WeightV1(value: weight)
            }

            try newLimit.encode(to: encoder)
        case .V3, .V4, .V5:
            try encode(to: encoder)
        }
    }
}

extension XcmUni.WeightLimit {
    init(v1Limit: Xcm.WeightLimit<Substrate.WeightV1>) {
        self = v1Limit.map { weight in
            Substrate.WeightV2(refTime: BigUInt(weight.value), proofSize: 0)
        }
    }
}
