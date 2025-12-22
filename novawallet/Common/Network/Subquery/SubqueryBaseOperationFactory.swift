import Foundation
import Operation_iOS
import SubstrateSdk

class SubqueryBaseOperationFactory {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func createRequestFactory(
        for query: String,
        variables: [String: String]? = nil
    ) -> BlockNetworkRequestFactory {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            var body: [String: JSON] = ["query": JSON.stringValue(query)]

            if let variables {
                let variablesJson = variables.mapValues { JSON.stringValue($0) }
                body["variables"] = JSON.dictionaryValue(variablesJson)
            }

            request.httpBody = try JSONEncoder().encode(JSON.dictionaryValue(body))
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }
    }

    func createOperation<P: Decodable, R>(
        for query: String,
        variables: [String: String]? = nil,
        resultHandler: @escaping (P) throws -> R
    ) -> BaseOperation<R> {
        let requestFactory = createRequestFactory(for: query, variables: variables)

        let resultFactory = AnyNetworkResultFactory<R> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<P>.self,
                from: data
            )
            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return try resultHandler(response)
            }
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createOperation<R: Decodable>(
        for query: String,
        variables: [String: String]? = nil
    ) -> BaseOperation<R> {
        let handler: (R) -> R = { $0 }
        return createOperation(for: query, variables: variables, resultHandler: handler)
    }
}
