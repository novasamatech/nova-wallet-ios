import Foundation
import SubstrateSdk

struct SubqueryErrors: Error, Decodable {
    struct SubqueryError: Error, Decodable {
        let message: String
    }

    let errors: [SubqueryError]
}

enum SubqueryResponse<D: Decodable>: Decodable {
    case data(_ value: D)
    case errors(_ value: SubqueryErrors)

    struct Model: Decodable {
        let data: D?
        let errors: [SubqueryErrors.SubqueryError]?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let json = try container.decode(Model.self)

        if let value = json.data {
            self = .data(value)
        } else if let errors = json.errors {
            self = .errors(SubqueryErrors(errors: errors))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unexpected value"
            )
        }
    }
}
