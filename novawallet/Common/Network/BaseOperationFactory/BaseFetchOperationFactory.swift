import Foundation
import RobinHood

class BaseFetchOperationFactory {
    func createFetchOperation<T>(from url: URL) -> BaseOperation<T> where T: Decodable {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<T> { data in
            try JSONDecoder().decode(T.self, from: data)
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
