import Foundation
import Operation_iOS

protocol DataOperationFactoryProtocol {
    func fetchData(from url: URL) -> BaseOperation<Data>
}

final class DataOperationFactory: DataOperationFactoryProtocol {
    let timeout: TimeInterval?
    let ignoresCache: Bool

    private let mirrorFetchFactory = ConfigMirrorFetchOperationFactory()

    init(timeout: TimeInterval? = nil, ignoresCache: Bool = false) {
        self.timeout = timeout
        self.ignoresCache = ignoresCache
    }

    func fetchData(from url: URL) -> BaseOperation<Data> {
        let resultFactory = AnyNetworkResultFactory<Data> { data in
            data
        }

        return mirrorFetchFactory.createFetchOperation(
            from: url,
            timeout: timeout,
            resultFactory: resultFactory
        ) { [ignoresCache] requestURL, requestTimeout in
            BlockNetworkRequestFactory {
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
