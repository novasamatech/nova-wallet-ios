import Foundation
import RobinHood
import SubstrateSdk

class SubqueryBaseOperationFactory {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func createRequestFactory(for query: String) -> BlockNetworkRequestFactory {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let body = JSON.dictionaryValue(["query": JSON.stringValue(query)])
            request.httpBody = try JSONEncoder().encode(body)
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
        resultHandler: @escaping (P) throws -> R
    ) -> BaseOperation<R> {
        let requestFactory = createRequestFactory(for: query)

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
}
