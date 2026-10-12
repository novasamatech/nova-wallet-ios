import Foundation
@testable import novawallet

final class HostAuthURLProtocol: URLProtocol {
    struct Reply {
        let status: Int
        var headers: [String: String] = [:]
        var body = Data()
    }

    private static let lock = NSLock()
    private static var recorded: [URLRequest] = []
    private static var tokenCount = 0
    static var business: ((URLRequest) -> Reply)?
    static var bootstrapFailure: Reply?

    static var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return recorded }
    static var businessRequests: [URLRequest] { requests.filter { !$0.url!.path.contains("/attestation/") } }

    static func reset() {
        lock.lock()
        recorded = []
        tokenCount = 0
        business = nil
        bootstrapFailure = nil
        lock.unlock()
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        var request = request
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open()
            var bytes = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                bytes.append(buffer, count: count)
            }
            stream.close()
            request.httpBody = bytes
        }
        Self.lock.lock()
        Self.recorded.append(request)
        let path = request.url!.path
        let isBootstrap = path.contains("/attestation/")
        if path.hasSuffix("/tokens") { Self.tokenCount += 1 }
        let token = Self.tokenCount
        let bootstrapFailure = Self.bootstrapFailure
        let handler = Self.business
        Self.lock.unlock()

        let reply: Reply
        if isBootstrap, let bootstrapFailure { reply = bootstrapFailure }
        else if path.hasSuffix("/challenges") || path.hasSuffix("/token-challenges") {
            reply = Reply(status: 200, body: Data(#"{"challenge":"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8","issued_at":1000,"expires_at":1060}"#.utf8))
        } else if path.hasSuffix("/register") { reply = Reply(status: 204) }
        else if path.hasSuffix("/tokens") {
            reply = Reply(status: 200, body: Data(#"{"access_token":"host-bearer-\#(token)","token_type":"Bearer","issued_at":1000,"expires_at":1900}"#.utf8))
        } else { reply = handler?(request) ?? Reply(status: 200, body: Data("{}".utf8)) }
        guard reply.status != 0 else {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: "HTTP/1.1", headerFields: reply.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
