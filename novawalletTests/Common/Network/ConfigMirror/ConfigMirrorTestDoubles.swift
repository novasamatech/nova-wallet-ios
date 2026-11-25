import Foundation
import Operation_iOS
@testable import novawallet

final class ConfigMirrorLoggerSpy: LoggerProtocol {
    private let mutex = NSLock()
    private var recordedWarnings: [String] = []
    private var recordedOthers: [String] = []

    var warnings: [String] {
        mutex.lock()
        defer { mutex.unlock() }

        return recordedWarnings
    }

    /// An empty string for a missing warning lets an assertion fail instead of trapping
    func warning(at index: Int) -> String {
        let warnings = self.warnings

        return warnings.indices.contains(index) ? warnings[index] : ""
    }

    var otherMessages: [String] {
        mutex.lock()
        defer { mutex.unlock() }

        return recordedOthers
    }

    func verbose(message: String, file _: String, function _: String, line _: Int) {
        recordOther(message)
    }

    func debug(message: String, file _: String, function _: String, line _: Int) {
        recordOther(message)
    }

    func info(message: String, file _: String, function _: String, line _: Int) {
        recordOther(message)
    }

    func warning(message: String, file _: String, function _: String, line _: Int) {
        mutex.lock()
        recordedWarnings.append(message)
        mutex.unlock()
    }

    func error(message: String, file _: String, function _: String, line _: Int) {
        recordOther(message)
    }

    private func recordOther(_ message: String) {
        mutex.lock()
        recordedOthers.append(message)
        mutex.unlock()
    }
}

final class ConfigMirrorTestClock {
    private let mutex = NSLock()
    private var currentUptime: TimeInterval = 1000

    var uptime: TimeInterval {
        mutex.lock()
        defer { mutex.unlock() }

        return currentUptime
    }

    func advance(by interval: TimeInterval) {
        mutex.lock()
        currentUptime += interval
        mutex.unlock()
    }
}

/// Stands in for the mirror-aware fetch: records what a factory asks for and answers
/// by passing the given response through the factory's own result factory.
final class ConfigMirrorFetchOperationFactorySpy: ConfigMirrorFetchFactoryProtocol {
    struct Call {
        let url: URL
        let timeout: TimeInterval?
        let request: URLRequest?
        let probeRequest: URLRequest?
    }

    let probeUrl: URL
    let probeTimeout: TimeInterval?

    var responseData = Data()
    var responseStatusCode = 200

    private(set) var calls: [Call] = []

    init(probeUrl: URL, probeTimeout: TimeInterval?) {
        self.probeUrl = probeUrl
        self.probeTimeout = probeTimeout
    }

    func createFetchOperation<T>(
        from url: URL,
        timeout: TimeInterval?,
        resultFactory: AnyNetworkResultFactory<T>,
        requestFactoryClosure: ConfigMirrorRequestFactoryClosure
    ) -> BaseOperation<T> {
        let call = Call(
            url: url,
            timeout: timeout,
            request: try? requestFactoryClosure(url, timeout).createRequest(),
            probeRequest: try? requestFactoryClosure(probeUrl, probeTimeout).createRequest()
        )

        calls.append(call)

        let response = HTTPURLResponse(
            url: url,
            statusCode: responseStatusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )

        switch resultFactory.createResult(data: responseData, response: response, error: nil) {
        case let .success(value):
            return .createWithResult(value)
        case let .failure(error):
            return .createWithError(error)
        }
    }
}
