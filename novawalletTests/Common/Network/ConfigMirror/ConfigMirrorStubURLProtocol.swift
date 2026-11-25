import Foundation

/// Answers the requests to the stubbed hosts and records them in the order they started loading.
final class ConfigMirrorStubURLProtocol: URLProtocol {
    enum Stub {
        case response(statusCode: Int, body: Data)
        case failure(URLError.Code)
        case hanging
    }

    private static let mutex = NSLock()
    private static var hosts: Set<String> = []
    private static var stubs: [String: Stub] = [:]
    private static var recordedRequests: [URLRequest] = []
    private static var requestObserver: ((URLRequest) -> Void)?
    private static var stopObserver: ((URLRequest) -> Void)?

    static var requests: [URLRequest] {
        locked { recordedRequests }
    }

    static var requestedUrls: [String] {
        requests.compactMap { $0.url?.absoluteString }
    }

    static func reset(hosts: Set<String> = []) {
        locked {
            self.hosts = hosts
            stubs = [:]
            recordedRequests = []
            requestObserver = nil
            stopObserver = nil
        }
    }

    static func stub(_ url: URL, with stub: Stub) {
        locked { stubs[url.absoluteString] = stub }
    }

    static func observeRequests(_ observer: @escaping (URLRequest) -> Void) {
        locked { requestObserver = observer }
    }

    static func observeStops(_ observer: @escaping (URLRequest) -> Void) {
        locked { stopObserver = observer }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString else {
            return false
        }

        // a url with a collapsed "https:/" has no host, so the whole string is matched
        return locked { hosts.contains { url.contains($0) } }
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (stub, observer) = Self.locked {
            Self.recordedRequests.append(request)
            return (request.url.flatMap { Self.stubs[$0.absoluteString] }, Self.requestObserver)
        }

        observer?(request)

        switch stub {
        case let .response(statusCode, body):
            guard
                let url = request.url,
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }

            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        case .hanging:
            break
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
        }
    }

    override func stopLoading() {
        let observer = Self.locked { Self.stopObserver }
        observer?(request)
    }

    private static func locked<T>(_ closure: () -> T) -> T {
        mutex.lock()
        defer { mutex.unlock() }

        return closure()
    }
}
