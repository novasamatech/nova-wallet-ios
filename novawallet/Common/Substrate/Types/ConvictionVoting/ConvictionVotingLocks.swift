import Foundation
import BigInt
import SubstrateSdk

extension ConvictionVoting {
    struct ClassLock: Decodable {
        let trackId: Referenda.TrackId
        let amount: BigUInt

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            trackId = try container.decode(StringScaleMapper<Referenda.TrackId>.self).value
            amount = try container.decode(StringScaleMapper<BigUInt>.self).value
        }
    }
}
