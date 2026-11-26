import Foundation

enum ConfigMirrorLoadEvent {
    case response(URLResponse)
    case data(Data)
    /// The answer was taken from the http cache and the server was not asked. Comes before `completed`.
    case servedFromLocalCache
    case completed(Error?)
}

protocol ConfigMirrorLoadTaskProtocol {
    func cancel()
}

extension URLSessionTask: ConfigMirrorLoadTaskProtocol {}

/// What differs between loading from the mirror and from the original url
struct ConfigMirrorLoadRules {
    /// When a redirect is not followed its response is reported as the answer
    let followsRedirects: Bool

    /// Tells whether a complete answer may be kept in the http cache.
    /// Without it the answer is kept by its own headers and the request's cache policy.
    let storageCondition: ((URLResponse, Data) -> Bool)?

    /// The request is performed the way `URLSession.shared` would perform it for the caller
    static let original = ConfigMirrorLoadRules(followsRedirects: true, storageCondition: nil)

    /// The mirror serves a file itself or not at all, and only a usable answer is worth keeping
    static func mirror(storageCondition: @escaping (URLResponse, Data) -> Bool) -> ConfigMirrorLoadRules {
        ConfigMirrorLoadRules(followsRedirects: false, storageCondition: storageCondition)
    }
}

protocol ConfigMirrorLoaderProtocol {
    /// Events of one request come in order and end with `completed`
    func load(
        _ request: URLRequest,
        rules: ConfigMirrorLoadRules,
        eventClosure: @escaping (ConfigMirrorLoadEvent) -> Void
    ) -> ConfigMirrorLoadTaskProtocol
}

/// Performs the requests of `ConfigMirrorURLProtocol` in a session of its own, which the protocol is not a part of.
/// By default the session uses the shared http cache, the one `URLSession.shared` keeps the same urls in.
final class ConfigMirrorLoader: NSObject {
    private let configuration: URLSessionConfiguration
    private let mutex = NSLock()
    private var loads: [Int: Load] = [:]

    // accessed under the mutex only
    private lazy var session: URLSession = {
        configuration.protocolClasses = configuration.protocolClasses?.filter { $0 != ConfigMirrorURLProtocol.self }

        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    init(configuration: URLSessionConfiguration = .default) {
        self.configuration = configuration
    }
}

extension ConfigMirrorLoader: ConfigMirrorLoaderProtocol {
    func load(
        _ request: URLRequest,
        rules: ConfigMirrorLoadRules,
        eventClosure: @escaping (ConfigMirrorLoadEvent) -> Void
    ) -> ConfigMirrorLoadTaskProtocol {
        mutex.lock()
        let task = session.dataTask(with: request)
        loads[task.taskIdentifier] = Load(rules: rules, eventClosure: eventClosure)
        mutex.unlock()

        task.resume()

        return task
    }
}

extension ConfigMirrorLoader: URLSessionDataDelegate {
    func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        pendingLoad(for: dataTask, isLast: false)?.eventClosure(.response(response))
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        pendingLoad(for: dataTask, isLast: false)?.eventClosure(.data(data))
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let followsRedirects = pendingLoad(for: task, isLast: false)?.rules.followsRedirects ?? true

        // without a new request the redirect response itself becomes the answer
        completionHandler(followsRedirects ? request : nil)
    }

    func urlSession(_: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard Self.isServedFromLocalCache(metrics.transactionMetrics.map(\.resourceFetchType)) else {
            return
        }

        pendingLoad(for: task, isLast: false)?.eventClosure(.servedFromLocalCache)
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        pendingLoad(for: task, isLast: true)?.eventClosure(.completed(error))
    }

    func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        willCacheResponse proposedResponse: CachedURLResponse,
        completionHandler: @escaping (CachedURLResponse?) -> Void
    ) {
        // a caller that doesn't read the http cache, such as the image downloader, keeps the answer itself
        switch dataTask.originalRequest?.cachePolicy {
        case .reloadIgnoringLocalCacheData, .reloadIgnoringLocalAndRemoteCacheData:
            completionHandler(nil)
            return
        default:
            break
        }

        let storageCondition = pendingLoad(for: dataTask, isLast: false)?.rules.storageCondition
        let isStorable = storageCondition?(proposedResponse.response, proposedResponse.data) ?? true

        completionHandler(isStorable ? proposedResponse : nil)
    }
}

extension ConfigMirrorLoader {
    /// A cached answer that was revalidated has a network transaction next to the cache one,
    /// so the server was not asked only when every transaction is a cache one
    static func isServedFromLocalCache(_ fetchTypes: [URLSessionTaskMetrics.ResourceFetchType]) -> Bool {
        !fetchTypes.isEmpty && fetchTypes.allSatisfy { $0 == .localCache }
    }
}

// MARK: Private

private extension ConfigMirrorLoader {
    struct Load {
        let rules: ConfigMirrorLoadRules
        let eventClosure: (ConfigMirrorLoadEvent) -> Void
    }

    func pendingLoad(for task: URLSessionTask, isLast: Bool) -> Load? {
        mutex.lock()
        defer { mutex.unlock() }

        return isLast ? loads.removeValue(forKey: task.taskIdentifier) : loads[task.taskIdentifier]
    }
}
