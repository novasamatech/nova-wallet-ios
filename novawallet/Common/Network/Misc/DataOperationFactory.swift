import Foundation
import Operation_iOS

protocol DataOperationFactoryProtocol {
    func fetchData(from url: URL) -> BaseOperation<Data>
}

final class DataOperationFactory: DataOperationFactoryProtocol {
    let timeout: TimeInterval?
    let ignoresCache: Bool

    private let mirrorFetchFactory: ConfigMirrorFetchFactoryProtocol

    init(
        timeout: TimeInterval? = nil,
        ignoresCache: Bool = false,
        mirrorFetchFactory: ConfigMirrorFetchFactoryProtocol = ConfigMirrorFetchOperationFactory()
    ) {
        self.timeout = timeout
        self.ignoresCache = ignoresCache
        self.mirrorFetchFactory = mirrorFetchFactory
    }

    func fetchData(from url: URL) -> BaseOperation<Data> {
        let resultFactory = AnyNetworkResultFactory<Data> { data in
            data
        }

        return mirrorFetchFactory.createFetchOperation(
            from: url,
            timeout: timeout,
            resultFactory: resultFactory
        ) { requestURL, requestTimeout in
            BlockNetworkRequestFactory { [ignoresCache] in
                var request = URLRequest(url: requestURL)
                request.httpMethod = HttpMethod.get.rawValue

                if let requestTimeout {
                    request.timeoutInterval = requestTimeout
                }

                if ignoresCache {
                    request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                }

                return request
            }
        }
    }
}
