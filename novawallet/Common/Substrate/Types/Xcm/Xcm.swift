import Foundation

enum Xcm {
    // swiftlint:disable identifier_name
    enum Version: UInt8, Comparable {
        case V0
        case V1
        case V2
        case V3
        case V4

        init?(rawName: String) {
            switch rawName {
            case "V0":
                self = .V0
            case "V1":
                self = .V1
            case "V2":
                self = .V2
            case "V3":
                self = .V3
            case "V4":
                self = .V4
            default:
                return nil
            }
        }

        static func < (lhs: Xcm.Version, rhs: Xcm.Version) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // swiftlint:enable identifier_name

    enum Outcome<W: Decodable, E: Decodable>: Decodable {
        struct Complete: Decodable {
            let used: W
        }

        struct Incomplete: Decodable {
            let used: W
            let error: E
        }

        struct Error: Decodable {
            let error: E
        }

        case complete(Complete)
        case incomplete(Incomplete)
        case error(Error)

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Complete":
                let model = try container.decode(Complete.self)
                self = .complete(model)
            case "Incomplete":
                let model = try container.decode(Incomplete.self)
                self = .incomplete(model)
            case "Error":
                let model = try container.decode(Error.self)
                self = .error(model)
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unsupported outcome \(type)"
                    )
                )
            }
        }

        var isComplete: Bool {
            switch self {
            case .complete:
                return true
            case .incomplete, .error:
                return false
            }
        }
    }
}
