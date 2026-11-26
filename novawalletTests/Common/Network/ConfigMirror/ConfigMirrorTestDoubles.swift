import Foundation
@testable import novawallet

final class ConfigMirrorLoggerSpy: LoggerProtocol {
    private let mutex = NSLock()
    private var recordedWarnings: [String] = []
    private var recordedErrors: [String] = []

    var warnings: [String] {
        mutex.lock()
        defer { mutex.unlock() }

        return recordedWarnings
    }

    var errors: [String] {
        mutex.lock()
        defer { mutex.unlock() }

        return recordedErrors
    }

    func warning(message: String, file _: String, function _: String, line _: Int) {
        mutex.lock()
        recordedWarnings.append(message)
        mutex.unlock()
    }

    func error(message: String, file _: String, function _: String, line _: Int) {
        mutex.lock()
        recordedErrors.append(message)
        mutex.unlock()
    }

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
}

final class ConfigMirrorTestClock {
    var time: TimeInterval = 1000
}

enum ConfigMirrorTestAnswer {
    static let commitHeaders = [ConfigMirrorConstants.commitHeader: "0123456789abcdef0123456789abcdef01234567"]

    /// A response the way the mirror sends it: every 200 of the mirror names its commit
    static func response(_ statusCode: Int, _ url: URL, headers: [String: String]? = commitHeaders) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
    }
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
    private(set) var rules: [ConfigMirrorLoadRules] = []
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
        rules: ConfigMirrorLoadRules,
        eventClosure: @escaping (ConfigMirrorLoadEvent) -> Void
    ) -> ConfigMirrorLoadTaskProtocol {
        mutex.lock()
        let index = requests.count
        requests.append(request)
        self.rules.append(rules)
        eventClosures.append(eventClosure)
        mutex.unlock()

        loadClosure()

        if let url = request.url, let body = answerClosure?(url.absoluteString) {
            let events: [ConfigMirrorLoadEvent] = [
                .response(ConfigMirrorTestAnswer.response(200, url)),
                .data(body),
                .completed(nil)
            ]

            DispatchQueue.global().async { events.forEach(eventClosure) }
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

/// Never fires by itself: a test triggers the deadline of the attempt it wants to be late
final class ConfigMirrorFakeScheduler: SchedulerProtocol {
    private weak var delegate: SchedulerDelegate?

    private(set) var delay: TimeInterval?
    private(set) var isCancelled = false

    var isScheduled: Bool { delay != nil && !isCancelled }

    init(delegate: SchedulerDelegate) {
        self.delegate = delegate
    }

    func notifyAfter(_ seconds: TimeInterval) {
        delay = seconds
    }

    func cancel() {
        isCancelled = true
    }

    func trigger() {
        delegate?.didTrigger(scheduler: self)
    }
}

final class ConfigMirrorAvailabilitySpy: ConfigMirrorAvailabilityProtocol {
    private let availability: ConfigMirrorAvailabilityProtocol

    private(set) var begunAttempts: [ConfigMirrorAttemptKind?] = []
    private(set) var endedAttempts: [String] = []

    init(availability: ConfigMirrorAvailabilityProtocol) {
        self.availability = availability
    }

    func beginAttempt() -> ConfigMirrorAttemptKind? {
        let kind = availability.beginAttempt()
        begunAttempts.append(kind)

        return kind
    }

    func endAttempt(_ kind: ConfigMirrorAttemptKind, verdict: ConfigMirrorAttemptVerdict) -> TimeInterval? {
        endedAttempts.append("\(kind) \(verdict)")

        return availability.endAttempt(kind, verdict: verdict)
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
