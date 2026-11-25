import XCTest
import Operation_iOS
@testable import novawallet

final class ConfigMirrorFetchOperationFactoryTests: ConfigMirrorFetchTestCase {
    func testUsesMirrorBodyAndSkipsGitHubWhenMirrorSucceeds() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let data = try fetch(gitHubUrl)

        // then
        XCTAssertEqual(data, mirrorBody)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
        XCTAssertTrue(logger.warnings.isEmpty)
    }

    func testFallsBackToGitHubWhenMirrorHasNoFile() throws {
        try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: 404, body: Data("{}".utf8)))
    }

    func testFallsBackToGitHubWhenMirrorIsNotReady() throws {
        try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: 503, body: Data()))
    }

    func testFallsBackToGitHubOnAnyOtherMirrorStatus() throws {
        for statusCode in [201, 204, 206, 301, 400, 401, 403, 429, 500, 502] {
            resetStubs()

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
        XCTAssertTrue(logger.warnings.isEmpty)
    }

    func testDoesNotValidateBodyOfNotMirroredUrl() throws {
        // given
        let emptyJsonUrl = try XCTUnwrap(URL(string: "https://other.novatest/some/empty.json"))

        ConfigMirrorStubURLProtocol.stub(emptyJsonUrl, with: .response(statusCode: 200, body: Data()))

        // when
        let data = try fetch(emptyJsonUrl)

        // then
        XCTAssertTrue(data.isEmpty)
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

    func testMirrorAttemptTakesAtMostHalfOfCallerTimeout() throws {
        // given
        let callerTimeout: TimeInterval = 10

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        _ = try fetch(gitHubUrl, timeout: callerTimeout)

        // then
        let timeouts = ConfigMirrorStubURLProtocol.requests.map(\.timeoutInterval)

        XCTAssertEqual(timeouts, [5, callerTimeout])
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

    func testDefaultMirrorTimeoutIsTheSharedConstant() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))

        let factory = ConfigMirrorFetchOperationFactory(
            urlResolver: resolver,
            availability: availability,
            logger: logger
        )

        // when
        let operation = factory.createFetchOperation(
            from: gitHubUrl,
            timeout: nil,
            resultFactory: AnyNetworkResultFactory<Data> { data in data }
        ) { requestUrl, requestTimeout in
            BlockNetworkRequestFactory {
                var request = URLRequest(url: requestUrl)
                request.timeoutInterval = requestTimeout ?? request.timeoutInterval
                return request
            }
        }

        _ = try run(operation)

        // then
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requests.map(\.timeoutInterval),
            [ConfigMirrorConstants.attemptTimeout]
        )
    }

    func testBuildsRequestFactoriesBeforeReturning() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        var builtUrls: [URL] = []

        // when
        let operation = makeFactory().createFetchOperation(
            from: gitHubUrl,
            timeout: nil,
            resultFactory: AnyNetworkResultFactory<Data> { data in data }
        ) { requestUrl, _ in
            builtUrls.append(requestUrl)

            return BlockNetworkRequestFactory { URLRequest(url: requestUrl) }
        }

        // then
        XCTAssertEqual(builtUrls, [gitHubUrl, mirrorUrl])

        _ = try run(operation)

        XCTAssertEqual(builtUrls, [gitHubUrl, mirrorUrl])
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
        XCTAssertEqual(try mapOperation.extractNoCancellableResultData(), #"{"source":"github"}"#)
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

        // a cancelled attempt says nothing about the mirror
        XCTAssertTrue(availability.isAvailable)
        XCTAssertTrue(logger.warnings.isEmpty)
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
