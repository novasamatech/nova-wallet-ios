import Foundation
import SubstrateSdk

extension Xcm {
    struct FeesPaidEvent<M: Decodable>: Decodable {
        let paying: JSON
        let assets: [M]

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            paying = try container.decode(JSON.self)
            assets = try container.decode([M].self)
        }
    }

    struct SentEvent<M: Decodable>: Decodable {
        let origin: JSON
        let destination: JSON
        let message: M
        let messageId: JSON

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            origin = try container.decode(JSON.self)
            destination = try container.decode(JSON.self)
            message = try container.decode(M.self)
            messageId = try container.decode(JSON.self)
        }
    }
}
