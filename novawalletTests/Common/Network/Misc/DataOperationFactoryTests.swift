import XCTest
import Operation_iOS
@testable import novawallet

final class DataOperationFactoryTests: ConfigMirrorFetchTestCase {
    private enum Settings {
        static let timeout: TimeInterval = 9
        static let probeTimeout: TimeInterval = 3
        static let getMethod = "GET"
    }

    private let probeUrl = URL(string: "https://probe.novatest/file.json")!

    func testAsksMirrorFetchForUrlWithOwnTimeoutAndReturnsItsOperation() throws {
        // given
        let spy = ConfigMirrorFetchOperationFactorySpy(probeUrl: probeUrl, probeTimeout: Settings.probeTimeout)
        spy.responseData = mirrorBody

        let factory = DataOperationFactory(timeout: Settings.timeout, ignoresCache: true, mirrorFetchFactory: spy)

        // when
        let data = try run(factory.fetchData(from: gitHubUrl))

        // then
        XCTAssertEqual(data, mirrorBody)
        XCTAssertEqual(spy.calls.map(\.url), [gitHubUrl])
        XCTAssertEqual(spy.calls.map(\.timeout), [Settings.timeout])
        XCTAssertTrue(ConfigMirrorStubURLProtocol.requests.isEmpty)
    }

    func testPassesNoTimeoutWhenItHasNone() {
        // given
        let spy = ConfigMirrorFetchOperationFactorySpy(probeUrl: probeUrl, probeTimeout: nil)

        // when
        _ = DataOperationFactory(mirrorFetchFactory: spy).fetchData(from: gitHubUrl)

        // then
        XCTAssertEqual(spy.calls.count, 1)
        XCTAssertNil(spy.calls.first?.timeout)
    }

    func testBuildsPlainGetForAnyUrlItIsAskedFor() throws {
        // given
        let spy = ConfigMirrorFetchOperationFactorySpy(probeUrl: probeUrl, probeTimeout: Settings.probeTimeout)

        // when
        _ = DataOperationFactory(timeout: Settings.timeout, ignoresCache: true, mirrorFetchFactory: spy)
            .fetchData(from: gitHubUrl)

        // then
        let call = try XCTUnwrap(spy.calls.first)
        let request = try XCTUnwrap(call.request)
        let probeRequest = try XCTUnwrap(call.probeRequest)

        XCTAssertEqual(request.url, gitHubUrl)
        XCTAssertEqual(request.timeoutInterval, Settings.timeout)
        XCTAssertEqual(probeRequest.url, probeUrl)
        XCTAssertEqual(probeRequest.timeoutInterval, Settings.probeTimeout)

        for builtRequest in [request, probeRequest] {
            XCTAssertEqual(builtRequest.httpMethod, Settings.getMethod)
            XCTAssertEqual(builtRequest.cachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
            XCTAssertTrue(builtRequest.allHTTPHeaderFields?.isEmpty ?? true)
        }
    }

    func testBuildsDefaultRequestWhenItHasNoSettings() throws {
        // given
        let spy = ConfigMirrorFetchOperationFactorySpy(probeUrl: probeUrl, probeTimeout: nil)

        // when
        _ = DataOperationFactory(mirrorFetchFactory: spy).fetchData(from: gitHubUrl)

        // then
        let request = try XCTUnwrap(spy.calls.first?.request)
        let plainRequest = URLRequest(url: gitHubUrl)

        XCTAssertEqual(request.timeoutInterval, plainRequest.timeoutInterval)
        XCTAssertEqual(request.cachePolicy, plainRequest.cachePolicy)
        XCTAssertTrue(request.allHTTPHeaderFields?.isEmpty ?? true)
    }

    func testReportsStatusFailure() {
        // given
        let spy = ConfigMirrorFetchOperationFactorySpy(probeUrl: probeUrl, probeTimeout: nil)
        spy.responseStatusCode = 404

        // when
        let operation = DataOperationFactory(mirrorFetchFactory: spy).fetchData(from: gitHubUrl)

        // then
        XCTAssertThrowsError(try run(operation)) { error in
            XCTAssertEqual(error as? NetworkResponseError, .resourceNotFound)
        }
    }

    // MARK: Together with the mirror fetch

    func testReadsMirrorFirst() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        let factory = DataOperationFactory(mirrorFetchFactory: makeFactory())

        // when
        let data = try run(factory.fetchData(from: gitHubUrl))

        // then
        XCTAssertEqual(data, mirrorBody)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
    }

    func testReadsGitHubWhenMirrorAnswersUnusableBody() throws {
        for body in [Data(), Data(#"[{"chainId":"#.utf8), Data("<html></html>".utf8)] {
            resetStubs()

            // given
            ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: body))
            ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

            let factory = DataOperationFactory(mirrorFetchFactory: makeFactory())

            // when
            let data = try run(factory.fetchData(from: gitHubUrl))

            // then
            XCTAssertEqual(data, gitHubBody)
            XCTAssertEqual(
                ConfigMirrorStubURLProtocol.requestedUrls,
                [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
            )
        }
    }

    func testKeepsCachePolicyForBothAttemptsAndSplitsTimeout() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 503, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        let factory = DataOperationFactory(
            timeout: Settings.timeout,
            ignoresCache: true,
            mirrorFetchFactory: makeFactory()
        )

        // when
        _ = try run(factory.fetchData(from: gitHubUrl))

        // then
        let requests = ConfigMirrorStubURLProtocol.requests

        XCTAssertEqual(requests.map(\.timeoutInterval), [Settings.timeout / 2, Settings.timeout])
        XCTAssertEqual(
            requests.map(\.cachePolicy),
            [.reloadIgnoringLocalAndRemoteCacheData, .reloadIgnoringLocalAndRemoteCacheData]
        )
    }
}
