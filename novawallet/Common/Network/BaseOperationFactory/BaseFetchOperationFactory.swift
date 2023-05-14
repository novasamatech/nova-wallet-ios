import Foundation
import RobinHood

class BaseFetchOperationFactory {
    func createRequestFactory(
        from url: URL,
        shouldUseCache: Bool,
        timeout: TimeInterval?
    ) -> BlockNetworkRequestFactory {
        BlockNetworkRequestFactory {
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
    }

    func createFetchOperation<T>(
        from url: URL,
        shouldUseCache: Bool = true,
        timeout: TimeInterval? = nil
    ) -> BaseOperation<T> where T: Decodable {
        let requestFactory = createRequestFactory(from: url, shouldUseCache: shouldUseCache, timeout: timeout)
        let resultFactory: AnyNetworkResultFactory<T> = createResultFactory()

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }

    func createResultFactory<T>() -> AnyNetworkResultFactory<T> where T: Decodable {
        AnyNetworkResultFactory<T> { data in
            try JSONDecoder().decode(T.self, from: data)
        }
    }
}
