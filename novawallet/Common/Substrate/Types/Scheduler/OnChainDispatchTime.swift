import Foundation
import SubstrateSdk

extension OnChainScheduler {
    enum DispatchTime: Decodable {
        case atBlock(_ blockNumber: Moment)
        case afterBlock(_ blockNumber: Moment)
        case unknown

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "At":
                let blockNumber = try container.decode(StringScaleMapper<Moment>.self).value
                self = .atBlock(blockNumber)
            case "After":
                let blockNumber = try container.decode(StringScaleMapper<Moment>.self).value
                self = .afterBlock(blockNumber)
            default:
                self = .unknown
            }
        }
    }
}
