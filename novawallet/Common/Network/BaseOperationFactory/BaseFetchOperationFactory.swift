import Foundation
import Operation_iOS

class BaseFetchOperationFactory {
    private let mirrorFetchFactory: ConfigMirrorFetchFactoryProtocol

    // Must stay the only designated initializer and callable without arguments: the subclasses rely on
    // the implicit `super.init()`, which the compiler adds only when there is a single designated one.
    init(mirrorFetchFactory: ConfigMirrorFetchFactoryProtocol = ConfigMirrorFetchOperationFactory()) {
        self.mirrorFetchFactory = mirrorFetchFactory
    }

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
        let resultFactory: AnyNetworkResultFactory<T> = createResultFactory()

        return mirrorFetchFactory.createFetchOperation(
            from: url,
            timeout: timeout,
            resultFactory: resultFactory
        ) { requestURL, requestTimeout in
            createRequestFactory(from: requestURL, shouldUseCache: shouldUseCache, timeout: requestTimeout)
        }
    }

    func createResultFactory<T>() -> AnyNetworkResultFactory<T> where T: Decodable {
        AnyNetworkResultFactory<T> { data in
            try JSONDecoder().decode(T.self, from: data)
        }
    }
}
