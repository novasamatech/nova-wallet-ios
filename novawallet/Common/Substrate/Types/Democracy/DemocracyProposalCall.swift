import Foundation
import SubstrateSdk

extension Democracy {
    struct ProposalCallAvailable: Decodable {
        @BytesCodable var data: Data
    }

    enum ProposalCall: Decodable {
        case available(ProposalCallAvailable)
        case unknown

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Available":
                let model = try container.decode(ProposalCallAvailable.self)
                self = .available(model)
            default:
                self = .unknown
            }
        }
    }
}
