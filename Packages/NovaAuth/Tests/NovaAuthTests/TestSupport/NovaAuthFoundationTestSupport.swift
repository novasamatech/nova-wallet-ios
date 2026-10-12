import Foundation
import XCTest
import Operation_iOS
@testable import NovaAuth

enum FoundationFixture {
    static let clientID = "6f2c1e4a-0000-4000-8000-000000000001"
    static let keyID = Data(0 ..< 32).base64EncodedString()
    static let challenge = String(keyID.dropLast())
    static let token = "synthetic-opaque-bearer"

    static func origin() throws -> NovaAuthOrigin { try NovaAuthOrigin("https://example.com") }
    static func context() throws -> NovaAuthContext { NovaAuthContext(origin: try origin(), generation: 1) }
    static func identity() throws -> NovaAuthAppIdentity {
        try NovaAuthAppIdentity(appID: "ABCDEFGHIJ.io.novafoundation.novawallet", environment: .production)
    }

    static func record(token: String = token) throws -> NovaAuthTokenRecord {
        NovaAuthTokenRecord(
            version: 1,
            context: try context(),
            flow: "bittensor-read",
            clientID: clientID,
            accessToken: token,
            issuedAt: 1000,
            expiresAt: 1300,
            issuanceStart: NovaAuthTime(bootID: "boot-a", continuousSeconds: 50),
            earlyRefreshSeconds: 70
        )
    }

    static func response(
        _ body: String,
        status: Int = 200,
        headers: [String: String] = [:],
        path: String = "/v1/attestation/profile-3/tokens"
    ) throws -> NovaAuthResponse {
        let url = try XCTUnwrap(URL(string: "https://example.com" + path))
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers))
        return NovaAuthResponse(response: response, body: Data(body.utf8))
    }
}

extension XCTestCase {
    func executeFoundation<T>(_ wrapper: CompoundOperationWrapper<T>, timeout: TimeInterval = 3) throws -> T {
        let finished = expectation(description: "operation completed")
        wrapper.targetOperation.completionBlock = { finished.fulfill() }
        let queue = OperationQueue()
        queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [finished], timeout: timeout)
        return try XCTUnwrap(wrapper.targetOperation.result).get()
    }
}

struct FoundationTestClock: NovaAuthClockProtocol {
    var time = NovaAuthTime(bootID: "boot-a", continuousSeconds: 50)
    func now() throws -> NovaAuthTime { time }
}

final class FoundationTestHTTP: NovaAuthHTTPProtocol {
    var requests: [URLRequest] = []
    var kinds: [NovaAuthHTTPKind] = []
    var response: NovaAuthResponse?
    var clears = 0

    func createResponseWrapper(
        for request: URLRequest,
        kind: NovaAuthHTTPKind,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        let operation = ClosureOperation<NovaAuthResponse> { [self] in
            try beforeSend()
            requests.append(request)
            kinds.append(kind)
            return try XCTUnwrap(response)
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func clearReadCache() { clears += 1 }
}
