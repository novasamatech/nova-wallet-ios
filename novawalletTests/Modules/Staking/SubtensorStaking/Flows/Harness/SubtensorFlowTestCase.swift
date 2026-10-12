import Foundation
import Operation_iOS
import XCTest
@testable import novawallet

enum SubtensorFlowLiteral {
    struct Invalid: Error {
        let literal: String
    }

    static func decimal(_ literal: String) throws -> Decimal {
        guard
            literal.range(of: #"\A-?[0-9]+(\.[0-9]+)?\z"#, options: .regularExpression) != nil,
            let value = Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX")) else {
            throw invalid(literal, expected: "a plain decimal")
        }

        return value
    }

    static func date(_ literal: String) throws -> Date {
        guard let value = ISO8601DateFormatter().date(from: literal) else {
            throw invalid(literal, expected: "an ISO 8601 date")
        }

        return value
    }

    static func rao(fromTao literal: String) throws -> Balance {
        guard let value = try? BittensorApiDecimal.atomic(literal, scale: 9) else {
            throw invalid(literal, expected: "a TAO amount with at most 9 decimals")
        }

        return value
    }

    private static func invalid(_ literal: String, expected: String) -> Invalid {
        XCTFail("Expected \(expected), got the literal \(literal)")

        return Invalid(literal: literal)
    }
}

struct SubtensorFlowAuthorizedRequest {
    let method: String
    let path: String
    let body: Data

    init(method: String, path: String, body: Data = Data()) {
        self.method = method
        self.path = path
        self.body = body
    }

    var contentType: String {
        body.isEmpty ? "" : "application/json"
    }
}

class SubtensorFlowTestCase: XCTestCase {
    let networkFee: Balance = 1_500_000
    let paidNetworkFee: UInt64 = 1_234_567

    override func setUp() {
        super.setUp()
        SubtensorFlowURLProtocol.install()
    }

    override func tearDown() {
        XCTAssertEqual(SubtensorFlowURLProtocol.uninstall(), [])
        super.tearDown()
    }

    func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        let completed = expectation(description: "Flow wrapper completed")

        wrapper.targetOperation.completionBlock = {
            completed.fulfill()
        }

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [completed], timeout: 10)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func runError<T>(_ wrapper: CompoundOperationWrapper<T>) -> Error? {
        do {
            _ = try run(wrapper)

            return nil
        } catch {
            return error
        }
    }

    func fetchSubnetsInfo(from service: SubtensorSubnetsServiceProtocol) throws -> SubtensorSubnetsInfo {
        let completed = expectation(description: "Subnets fetched")
        var result: Result<SubtensorSubnetsInfo, Error>?

        service.fetchSubnetsInfo(runningCompletionIn: DispatchQueue(label: "flow.subnets")) { fetched in
            result = fetched
            completed.fulfill()
        }

        wait(for: [completed], timeout: 10)

        return try XCTUnwrap(result).get()
    }

    func decimal(_ literal: String) throws -> Decimal {
        try SubtensorFlowLiteral.decimal(literal)
    }

    func date(_ literal: String) throws -> Date {
        try SubtensorFlowLiteral.date(literal)
    }

    func requestLines() -> [String] {
        SubtensorFlowURLProtocol.recordedRequests.filter { !$0.url.contains("/v1/attestation/") }.map { "\($0.method) \($0.url)" }
    }

    func assertAuthorizedRequests(_ world: SubtensorFlowWorld, paths: [String]) {
        assertAuthorizedRequests(world, requests: paths.map { SubtensorFlowAuthorizedRequest(method: "GET", path: $0) })
    }

    func assertAuthorizedRequests(_ world: SubtensorFlowWorld, requests: [SubtensorFlowAuthorizedRequest]) {
        let backendRequests = SubtensorFlowURLProtocol.recordedRequests.filter {
            $0.url.hasPrefix("https://bittensor.test/v1/bittensor/")
        }

        XCTAssertEqual(backendRequests.compactMap { URL(string: $0.url)?.path }, requests.map(\.path))
        XCTAssertEqual(backendRequests.map(\.method), requests.map(\.method))
        XCTAssertEqual(backendRequests.map(\.body), requests.map(\.body))
        XCTAssertTrue(backendRequests.allSatisfy { $0.headers["Authorization"] == "Bearer flow-shared-bearer" })
        XCTAssertEqual(backendRequests.map { $0.headers["Content-Type"] ?? "" }, requests.map(\.contentType))
        XCTAssertEqual(world.auth.harness.apple.attestations, 1)
        XCTAssertEqual(world.auth.harness.apple.assertions, 1)
        let bootstrap = SubtensorFlowURLProtocol.recordedRequests.filter { $0.url.contains("/v1/attestation/") }
        XCTAssertEqual(bootstrap.compactMap { URL(string: $0.url)?.lastPathComponent }, ["challenges", "register", "token-challenges", "tokens"])
    }

    func isRouteNotPublished(_ error: Error?) -> Bool {
        guard case .routeNotPublished? = error as? BittensorApiError else {
            return false
        }

        return true
    }
}
