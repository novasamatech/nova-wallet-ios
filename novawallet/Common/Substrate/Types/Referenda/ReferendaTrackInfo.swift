import Foundation
import SubstrateSdk
import BigInt

extension Referenda {
    struct TrackInfo: Decodable {
        let name: String
        @StringCodable var maxDeciding: UInt32
        @StringCodable var decisionDeposit: BigUInt
        @StringCodable var preparePeriod: Moment
        @StringCodable var decisionPeriod: Moment
        @StringCodable var confirmPeriod: Moment
        @StringCodable var minEnactmentPeriod: Moment
        let minApproval: Referenda.Curve
        let minSupport: Referenda.Curve
    }

    struct Track: Decodable {
        let trackId: Referenda.TrackId
        let info: TrackInfo

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            trackId = try container.decode(StringScaleMapper<Referenda.TrackId>.self).value
            info = try container.decode(TrackInfo.self)
        }
    }
}
