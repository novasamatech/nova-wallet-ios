import Foundation

enum Xcm {
    // swiftlint:disable identifier_name
    enum Version: UInt8, Comparable, CaseIterable {
        case V0
        case V1
        case V2
        case V3
        case V4
        case V5

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
            case "V5":
                self = .V5
            default:
                return nil
            }
        }

        var rawName: String {
            "V\(rawValue)"
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

        struct ErrorModel: Decodable {
            let error: E
        }

        case complete(Complete)
        case incomplete(Incomplete)
        case error(ErrorModel)

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
                let model = try container.decode(ErrorModel.self)
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

        @discardableResult
        func ensureCompleteOrError(_ errorClosure: (E) -> Error) throws -> W {
            switch self {
            case let .complete(complete):
                return complete.used
            case let .incomplete(incomplete):
                throw errorClosure(incomplete.error)
            case let .error(errorModel):
                throw errorClosure(errorModel.error)
            }
        }
    }
}
