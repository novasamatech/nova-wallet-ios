import Foundation
import RobinHood

class BaseFetchOperationFactory {
    func createFetchOperation<T>(
        from url: URL,
        shouldUseCache: Bool = true,
        timeout: TimeInterval? = nil,
        hash: String? = nil
    ) -> BaseOperation<T> where T: Decodable {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            if !shouldUseCache {
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            }

            if let timeout = timeout {
                request.timeoutInterval = timeout
            }

            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory: AnyNetworkResultFactory<T> = createResultFactory(hash: hash)

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createResultFactory<T>(hash _: String?) -> AnyNetworkResultFactory<T> where T: Decodable {
        AnyNetworkResultFactory<T> { data in
            try JSONDecoder().decode(T.self, from: data)
        }
    }
}
