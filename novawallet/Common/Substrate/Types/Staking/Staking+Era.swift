import Foundation
import SubstrateSdk

extension Staking {
    struct BondedEra: Decodable {
        let era: EraIndex
        let startSessionIndex: SessionIndex

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            era = try unkeyedContainer.decode(StringScaleMapper<EraIndex>.self).value
            startSessionIndex = try unkeyedContainer.decode(StringScaleMapper<SessionIndex>.self).value
        }
    }
}
