import Foundation
import Operation_iOS

enum RaiseStatusCode: Int {
    case success = 200
    case created = 201
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case preconditionFailed = 412
    case unprocessableEntry = 422
    case notAcceptable = 406
    case alreadyExists = 409
    case internalServerError = 500
    case serverUnavailable = 503

    var isOk: Bool {
        switch self {
        case .success,
             .created:
            true
        default:
            false
        }
    }
}

struct RaiseApiError: Error {
    let statusCode: RaiseStatusCode
    let details: String?
}

class BaseRaiseResultFactory<R> {
    typealias ResultType = R

    func parseReponse(from _: Data) throws -> R {
        fatalError("Must be overriden by subsclass")
    }
}

extension BaseRaiseResultFactory: NetworkResultFactoryProtocol {
    func createResult(data: Data?, response: URLResponse?, error: Error?) -> Result<ResultType, Error> {
        if let connectionError = error {
            return .failure(connectionError)
        }

        guard let httpUrlResponse = response as? HTTPURLResponse else {
            return .failure(NetworkBaseError.unexpectedResponseObject)
        }

        guard let statusCode = RaiseStatusCode(rawValue: httpUrlResponse.statusCode) else {
            return .failure(NetworkResponseError.unexpectedStatusCode)
        }

        if statusCode.isOk {
            guard let documentData = data else {
                return .failure(NetworkBaseError.unexpectedEmptyData)
            }

            do {
                let result = try parseReponse(from: documentData)

                return .success(result)
            } catch {
                return .failure(error)
            }
        } else {
            let details = data.flatMap { String(data: $0, encoding: .utf8) }

            let error = RaiseApiError(statusCode: statusCode, details: details)

            return .failure(error)
        }
    }
}

final class RaiseAttributesResultFactory<R: Decodable>: BaseRaiseResultFactory<R> {
    override func parseReponse(from data: Data) throws -> R {
        try JSONDecoder().decode(
            RaiseResponse<R>.self,
            from: data
        ).data.attributes
    }
}

final class RaiseResultFactory<R: Decodable>: BaseRaiseResultFactory<RaiseResponse<R>> {
    override func parseReponse(from data: Data) throws -> RaiseResponse<R> {
        try JSONDecoder().decode(
            RaiseResponse<R>.self,
            from: data
        )
    }
}

final class RaiseListResultFactory<I: Decodable>: BaseRaiseResultFactory<RaiseListResult<I>> {
    let filter: ((I) -> Bool)?
    init(filter: ((I) -> Bool)? = nil) {
        self.filter = filter
    }

    override func parseReponse(from data: Data) throws -> RaiseListResult<I> {
        let response = try JSONDecoder().decode(
            RaiseListResponse<I>.self,
            from: data
        )

        let items = response.data.map { RaiseResource<I>(identifier: $0.identifier, attributes: $0.attributes) }
        return .init(
            items: filter.map { filter in items.filter { filter($0.attributes) } } ?? items,
            total: response.meta?.total ?? 0
        )
    }
}
