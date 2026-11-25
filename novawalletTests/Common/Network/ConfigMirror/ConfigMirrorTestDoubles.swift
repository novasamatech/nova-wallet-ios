import Foundation
@testable import novawallet

final class ConfigMirrorLoggerSpy: LoggerProtocol {
    private let mutex = NSLock()
    private var recordedWarnings: [String] = []

    var warnings: [String] {
        mutex.lock()
        defer { mutex.unlock() }

        return recordedWarnings
    }

    func warning(message: String, file _: String, function _: String, line _: Int) {
        mutex.lock()
        recordedWarnings.append(message)
        mutex.unlock()
    }

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
}

final class ConfigMirrorTestClock {
    var uptime: TimeInterval = 1000
}

/// Keeps the requests it is asked to load. A test either sends the events itself
/// or sets `answerClosure` to have every request answered with 200 from a background queue.
final class ConfigMirrorFakeLoader: ConfigMirrorLoaderProtocol {
    private struct Task: ConfigMirrorLoadTaskProtocol {
        let cancelClosure: () -> Void

        func cancel() {
            cancelClosure()
        }
    }

    private let mutex = NSLock()
    private var eventClosures: [(ConfigMirrorLoadEvent) -> Void] = []
    private(set) var requests: [URLRequest] = []
    private(set) var cancelledRequests: [Int] = []

    var answerClosure: ((String) -> Data)?
    var loadClosure: () -> Void = {}
    var cancelClosure: () -> Void = {}

    var requestedUrls: [String] {
        mutex.lock()
        defer { mutex.unlock() }

        return requests.compactMap { $0.url?.absoluteString }
    }

    func load(
        _ request: URLRequest,
        eventClosure: @escaping (ConfigMirrorLoadEvent) -> Void
    ) -> ConfigMirrorLoadTaskProtocol {
        mutex.lock()
        let index = requests.count
        requests.append(request)
        eventClosures.append(eventClosure)
        mutex.unlock()

        loadClosure()

        if let url = request.url, let body = answerClosure?(url.absoluteString) {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)
            let events = [response.map { ConfigMirrorLoadEvent.response($0) }, .data(body), .completed(nil)]

            DispatchQueue.global().async { events.compactMap { $0 }.forEach(eventClosure) }
        }

        return Task { [weak self] in
            self?.mutex.lock()
            self?.cancelledRequests.append(index)
            self?.mutex.unlock()

            self?.cancelClosure()
        }
    }

    func send(_ events: [ConfigMirrorLoadEvent], toRequest index: Int) {
        guard eventClosures.indices.contains(index) else {
            return
        }

        events.forEach(eventClosures[index])
    }
}

/// Writes down what the protocol hands to its client, one line per call
final class ConfigMirrorClientSpy: NSObject, URLProtocolClient {
    private(set) var events: [String] = []

    func urlProtocol(_: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let isStored = policy != .notAllowed

        events.append("response \(statusCode) \(response.url?.absoluteString ?? "") stored=\(isStored)")
    }

    func urlProtocol(_: URLProtocol, didLoad data: Data) {
        events.append("data \(String(data: data, encoding: .utf8) ?? "")")
    }

    func urlProtocolDidFinishLoading(_: URLProtocol) {
        events.append("finished")
    }

    func urlProtocol(_: URLProtocol, didFailWithError error: Error) {
        events.append("failed \((error as NSError).code)")
    }

    func urlProtocol(_: URLProtocol, wasRedirectedTo _: URLRequest, redirectResponse _: URLResponse) {}
    func urlProtocol(_: URLProtocol, cachedResponseIsValid _: CachedURLResponse) {}
    func urlProtocol(_: URLProtocol, didReceive _: URLAuthenticationChallenge) {}
    func urlProtocol(_: URLProtocol, didCancel _: URLAuthenticationChallenge) {}
}
