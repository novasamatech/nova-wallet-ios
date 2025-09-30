import Foundation
import SubstrateSdk

extension Staking {
    typealias EraIndex = UInt32
    typealias EraRange = (start: EraIndex, end: EraIndex)

    struct BondedEra: Decodable {
        let era: EraIndex
        let startSessionIndex: SessionIndex

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            era = try unkeyedContainer.decode(StringScaleMapper<EraIndex>.self).value
            startSessionIndex = try unkeyedContainer.decode(StringScaleMapper<SessionIndex>.self).value
        }
    }

    struct ActiveEraInfo: Codable, Equatable {
        @StringCodable var index: EraIndex
    }
}
