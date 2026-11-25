import Foundation
import Operation_iOS

protocol DataOperationFactoryProtocol {
    func fetchData(from url: URL) -> BaseOperation<Data>
}

final class DataOperationFactory: DataOperationFactoryProtocol {
    let timeout: TimeInterval?
    let ignoresCache: Bool

    init(timeout: TimeInterval? = nil, ignoresCache: Bool = false) {
        self.timeout = timeout
        self.ignoresCache = ignoresCache
    }

    func fetchData(from url: URL) -> BaseOperation<Data> {
        let requestFactory = BlockNetworkRequestFactory { [timeout, ignoresCache] in
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue

            if let timeout {
                request.timeoutInterval = timeout
            }

            if ignoresCache {
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            }

            return request
        }

        let resultFactory = AnyNetworkResultFactory<Data> { data in
            data
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
