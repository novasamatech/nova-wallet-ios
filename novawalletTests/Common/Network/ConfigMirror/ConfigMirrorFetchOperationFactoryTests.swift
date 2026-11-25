import XCTest
import Operation_iOS
@testable import novawallet

final class ConfigMirrorFetchOperationFactoryTests: XCTestCase {
    private enum Constants {
        static let mirrorHost = "mirror.novatest"
        static let gitHubHost = "github.novatest"
        static let otherHost = "other.novatest"
        static let callerTimeout: TimeInterval = 30
        static let mirrorTimeout: TimeInterval = 7
        static let expectationTimeout: TimeInterval = 10
    }

    private let gitHubUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/chains/v23/chains.json")!
    private let mirrorUrl = URL(string: "https://mirror.novatest/v1/config/chains/v23/chains.json")!
    private let otherUrl = URL(string: "https://other.novatest/novasamatech/branding/master/logo.png")!

    private let mirrorBody = Data("mirror".utf8)
    private let gitHubBody = Data("github".utf8)
    private let otherBody = Data("other".utf8)

    private let operationQueue = OperationQueue()

    override func setUp() {
        super.setUp()

        ConfigMirrorStubURLProtocol.reset(
            hosts: [Constants.mirrorHost, Constants.gitHubHost, Constants.otherHost]
        )

        XCTAssertTrue(URLProtocol.registerClass(ConfigMirrorStubURLProtocol.self))
    }

    override func tearDown() {
        URLProtocol.unregisterClass(ConfigMirrorStubURLProtocol.self)
        ConfigMirrorStubURLProtocol.reset()

        super.tearDown()
    }

    func testUsesMirrorBodyAndSkipsGitHubWhenMirrorSucceeds() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let data = try fetch(gitHubUrl)

        // then
        XCTAssertEqual(data, mirrorBody)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
    }

    func testFallsBackToGitHubWhenMirrorHasNoFile() throws {
        try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: 404, body: Data("{}".utf8)))
    }

    func testFallsBackToGitHubWhenMirrorIsNotReady() throws {
        try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: 503, body: Data()))
    }

    func testFallsBackToGitHubOnAnyOtherMirrorStatus() throws {
        for statusCode in [204, 301, 400, 401, 403, 429, 500, 502] {
            ConfigMirrorStubURLProtocol.reset(
                hosts: [Constants.mirrorHost, Constants.gitHubHost, Constants.otherHost]
            )

            try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: statusCode, body: mirrorBody))
        }
    }

    func testFallsBackToGitHubOnMirrorNetworkError() throws {
        try assertFallsBackToGitHub(whenMirrorAnswers: .failure(.cannotConnectToHost))
    }

    func testFallsBackToGitHubOnMirrorTlsError() throws {
        try assertFallsBackToGitHub(whenMirrorAnswers: .failure(.secureConnectionFailed))
    }

    func testFallsBackToGitHubWhenMirrorTimesOut() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .hanging)
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let data = try fetch(gitHubUrl, mirrorTimeout: 0.5)

        // then
        XCTAssertEqual(data, gitHubBody)
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
        )
    }

    func testReportsGitHubFailureWhenBothFail() {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 503, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 404, body: Data()))

        // when
        XCTAssertThrowsError(try fetch(gitHubUrl)) { error in
            // then
            XCTAssertEqual(error as? NetworkResponseError, .resourceNotFound)
        }

        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
        )
    }

    func testFetchesNotMirroredUrlOnce() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(otherUrl, with: .response(statusCode: 200, body: otherBody))

        // when
        let operation = makeOperation(for: otherUrl, timeout: Constants.callerTimeout)
        let data = try run(operation)

        // then
        XCTAssertTrue(operation is NetworkOperation<Data>)
        XCTAssertEqual(data, otherBody)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [otherUrl.absoluteString])
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requests.first?.timeoutInterval, Constants.callerTimeout)
    }

    func testDoesNotFallBackWhenNotMirroredUrlFails() {
        // given
        ConfigMirrorStubURLProtocol.stub(otherUrl, with: .response(statusCode: 404, body: Data()))

        // when
        XCTAssertThrowsError(try fetch(otherUrl)) { error in
            // then
            XCTAssertEqual(error as? NetworkResponseError, .resourceNotFound)
        }

        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [otherUrl.absoluteString])
    }

    func testBoundsMirrorAttemptAndKeepsCallerTimeoutForGitHub() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        _ = try fetch(gitHubUrl, timeout: Constants.callerTimeout)

        // then
        let timeouts = ConfigMirrorStubURLProtocol.requests.map(\.timeoutInterval)

        XCTAssertEqual(timeouts, [Constants.mirrorTimeout, Constants.callerTimeout])
    }

    func testMirrorAttemptIsNeverLongerThanCallerTimeout() throws {
        // given
        let callerTimeout: TimeInterval = 3

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        _ = try fetch(gitHubUrl, timeout: callerTimeout)

        // then
        let timeouts = ConfigMirrorStubURLProtocol.requests.map(\.timeoutInterval)

        XCTAssertEqual(timeouts, [callerTimeout, callerTimeout])
    }

    func testBoundsMirrorAttemptWhenCallerHasNoTimeout() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        _ = try fetch(gitHubUrl, timeout: nil)

        // then
        let timeouts = ConfigMirrorStubURLProtocol.requests.map(\.timeoutInterval)
        let defaultTimeout = URLRequest(url: gitHubUrl).timeoutInterval

        XCTAssertEqual(timeouts, [Constants.mirrorTimeout, defaultTimeout])
    }

    func testDependentOperationReadsFallbackResult() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .failure(.networkConnectionLost))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        let fetchOperation = makeOperation(for: gitHubUrl, timeout: nil)

        let mapOperation = ClosureOperation<String?> {
            let data = try fetchOperation.extractNoCancellableResultData()
            return String(data: data, encoding: .utf8)
        }

        mapOperation.addDependency(fetchOperation)

        // when
        let serialQueue = OperationQueue()
        serialQueue.maxConcurrentOperationCount = 1
        serialQueue.addOperations([fetchOperation, mapOperation], waitUntilFinished: true)

        // then
        XCTAssertEqual(try mapOperation.extractNoCancellableResultData(), "github")
    }

    func testCancellationStopsMirrorAttemptAndSkipsGitHub() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .hanging)
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))
        ConfigMirrorStubURLProtocol.stub(otherUrl, with: .response(statusCode: 200, body: otherBody))

        let mirrorUrl = mirrorUrl

        let mirrorRequested = expectation(description: "mirror requested")
        mirrorRequested.assertForOverFulfill = false

        ConfigMirrorStubURLProtocol.observeRequests { request in
            if request.url == mirrorUrl {
                mirrorRequested.fulfill()
            }
        }

        let mirrorStopped = expectation(description: "mirror request stopped")
        mirrorStopped.assertForOverFulfill = false

        ConfigMirrorStubURLProtocol.observeStops { request in
            if request.url == mirrorUrl {
                mirrorStopped.fulfill()
            }
        }

        let operation = makeOperation(for: gitHubUrl, timeout: Constants.callerTimeout)

        let finished = expectation(description: "operation finished")
        operation.completionBlock = { finished.fulfill() }

        // when
        operationQueue.addOperation(operation)

        wait(for: [mirrorRequested], timeout: Constants.expectationTimeout)

        operation.cancel()

        wait(for: [finished, mirrorStopped], timeout: Constants.expectationTimeout)

        // a request that completes after the cancellation shows that nothing else was sent in between
        XCTAssertEqual(try fetch(otherUrl), otherBody)

        // then
        XCTAssertTrue(operation.isCancelled)
        XCTAssertNil(operation.result)
        XCTAssertThrowsError(try operation.extractNoCancellableResultData())
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, otherUrl.absoluteString]
        )
    }

    func testCancellationDuringGitHubAttemptStopsIt() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .hanging)

        let gitHubUrl = gitHubUrl

        let gitHubRequested = expectation(description: "github requested")
        gitHubRequested.assertForOverFulfill = false

        ConfigMirrorStubURLProtocol.observeRequests { request in
            if request.url == gitHubUrl {
                gitHubRequested.fulfill()
            }
        }

        let gitHubStopped = expectation(description: "github request stopped")
        gitHubStopped.assertForOverFulfill = false

        ConfigMirrorStubURLProtocol.observeStops { request in
            if request.url == gitHubUrl {
                gitHubStopped.fulfill()
            }
        }

        let operation = makeOperation(for: gitHubUrl, timeout: Constants.callerTimeout)

        let finished = expectation(description: "operation finished")
        operation.completionBlock = { finished.fulfill() }

        // when
        operationQueue.addOperation(operation)

        wait(for: [gitHubRequested], timeout: Constants.expectationTimeout)

        operation.cancel()

        // then
        wait(for: [finished, gitHubStopped], timeout: Constants.expectationTimeout)

        XCTAssertNil(operation.result)
    }
}

private extension ConfigMirrorFetchOperationFactoryTests {
    func makeOperation(
        for url: URL,
        timeout: TimeInterval?,
        mirrorTimeout: TimeInterval = Constants.mirrorTimeout
    ) -> BaseOperation<Data> {
        let resolver = ConfigMirrorURLResolver(
            mirrorBaseURL: URL(string: "https://\(Constants.mirrorHost)/v1/config/")!,
            sources: ["\(Constants.gitHubHost)/novasamatech/nova-utils/master/"]
        )

        let factory = ConfigMirrorFetchOperationFactory(urlResolver: resolver, mirrorTimeout: mirrorTimeout)

        return factory.createFetchOperation(
            from: url,
            timeout: timeout,
            resultFactory: AnyNetworkResultFactory<Data> { data in data }
        ) { requestUrl, requestTimeout in
            BlockNetworkRequestFactory {
                var request = URLRequest(url: requestUrl)
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

                if let requestTimeout {
                    request.timeoutInterval = requestTimeout
                }

                return request
            }
        }
    }

    func fetch(
        _ url: URL,
        timeout: TimeInterval? = Constants.callerTimeout,
        mirrorTimeout: TimeInterval = Constants.mirrorTimeout
    ) throws -> Data {
        try run(makeOperation(for: url, timeout: timeout, mirrorTimeout: mirrorTimeout))
    }

    func run(_ operation: BaseOperation<Data>) throws -> Data {
        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    func assertFallsBackToGitHub(
        whenMirrorAnswers mirrorStub: ConfigMirrorStubURLProtocol.Stub,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: mirrorStub)
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let data = try fetch(gitHubUrl)

        // then
        XCTAssertEqual(data, gitHubBody, file: file, line: line)
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString],
            file: file,
            line: line
        )
    }
}
