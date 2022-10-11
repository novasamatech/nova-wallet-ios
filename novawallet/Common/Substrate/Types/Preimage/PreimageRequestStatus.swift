import Foundation
import SubstrateSdk

extension Preimage {
    struct RequestStatusUnrequested: Decodable {
        @StringCodable var len: UInt32
    }

    struct RequestStatusRequested: Decodable {
        @OptionStringCodable var len: UInt32?
    }

    enum RequestStatus: Decodable {
        case unrequested(RequestStatusUnrequested)
        case requested(RequestStatusRequested)
        case unknown

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "Unrequested":
                let status = try container.decode(RequestStatusUnrequested.self)
                self = .unrequested(status)
            case "Requested":
                let status = try container.decode(RequestStatusRequested.self)
                self = .requested(status)
            default:
                self = .unknown
            }
        }

        var length: UInt32? {
            switch self {
            case let .unrequested(requestStatusUnrequested):
                return requestStatusUnrequested.len
            case let .requested(requestStatusRequested):
                return requestStatusRequested.len
            case .unknown:
                return nil
            }
        }
    }
}
