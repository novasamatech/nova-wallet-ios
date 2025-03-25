import Foundation
import SubstrateSdk

enum Substrate {
    enum Result<T: Decodable, E: Decodable>: Decodable {
        case success(T)
        case failure(E)

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Ok":
                let value = try container.decode(T.self)
                self = .success(value)
            case "Err":
                let value = try container.decode(E.self)
                self = .failure(value)
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Unsupported case \(type)"
                    )
                )
            }
        }

        var isOk: Bool {
            switch self {
            case .success:
                return true
            case .failure:
                return false
            }
        }

        @discardableResult
        func ensureOkOrError(_ closure: (E) -> Error) throws -> T {
            switch self {
            case let .success(model):
                return model
            case let .failure(error):
                throw closure(error)
            }
        }
    }
}
