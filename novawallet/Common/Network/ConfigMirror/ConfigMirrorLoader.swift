import Foundation

enum ConfigMirrorLoadEvent {
    case response(URLResponse)
    case data(Data)
    case completed(Error?)
}

protocol ConfigMirrorLoadTaskProtocol {
    func cancel()
}

extension URLSessionTask: ConfigMirrorLoadTaskProtocol {}

protocol ConfigMirrorLoaderProtocol {
    /// Events of one request come in order and end with `completed`
    func load(
        _ request: URLRequest,
        eventClosure: @escaping (ConfigMirrorLoadEvent) -> Void
    ) -> ConfigMirrorLoadTaskProtocol
}

/// Performs the requests of `ConfigMirrorURLProtocol` in a session of its own, which the protocol is not a part of.
/// By default the session uses the shared http cache, the one `URLSession.shared` keeps the same urls in.
final class ConfigMirrorLoader: NSObject {
    private let configuration: URLSessionConfiguration
    private let mutex = NSLock()
    private var eventClosures: [Int: (ConfigMirrorLoadEvent) -> Void] = [:]

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
        eventClosure: @escaping (ConfigMirrorLoadEvent) -> Void
    ) -> ConfigMirrorLoadTaskProtocol {
        mutex.lock()
        let task = session.dataTask(with: request)
        eventClosures[task.taskIdentifier] = eventClosure
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
        eventClosure(for: dataTask, isLast: false)?(.response(response))
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        eventClosure(for: dataTask, isLast: false)?(.data(data))
    }

    func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        eventClosure(for: task, isLast: true)?(.completed(error))
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
        default:
            completionHandler(proposedResponse)
        }
    }
}

private extension ConfigMirrorLoader {
    func eventClosure(for task: URLSessionTask, isLast: Bool) -> ((ConfigMirrorLoadEvent) -> Void)? {
        mutex.lock()
        defer { mutex.unlock() }

        return isLast ? eventClosures.removeValue(forKey: task.taskIdentifier) : eventClosures[task.taskIdentifier]
    }
}
