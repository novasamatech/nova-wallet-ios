import XCTest
import Operation_iOS
@testable import novawallet

final class BaseFetchOperationFactoryTests: ConfigMirrorFetchTestCase {
    struct Payload: Decodable, Equatable {
        let source: String
    }

    private final class Subclass: BaseFetchOperationFactory {
        let name: String

        init(name: String) {
            self.name = name
        }
    }

    private enum Settings {
        static let timeout: TimeInterval = 8
        static let probeTimeout: TimeInterval = 2
        static let getMethod = "GET"
    }

    private let probeUrl = URL(string: "https://probe.novatest/file.json")!

    func testAsksMirrorFetchForUrlWithGivenTimeoutAndDecodesItsAnswer() throws {
        // given
        let spy = ConfigMirrorFetchOperationFactorySpy(probeUrl: probeUrl, probeTimeout: Settings.probeTimeout)
        spy.responseData = mirrorBody

        let factory = BaseFetchOperationFactory(mirrorFetchFactory: spy)

        // when
        let payload: Payload = try run(
            factory.createFetchOperation(from: gitHubUrl, shouldUseCache: false, timeout: Settings.timeout)
        )

        // then
        XCTAssertEqual(payload, Payload(source: "mirror"))
        XCTAssertEqual(spy.calls.map(\.url), [gitHubUrl])
        XCTAssertEqual(spy.calls.map(\.timeout), [Settings.timeout])
        XCTAssertTrue(ConfigMirrorStubURLProtocol.requests.isEmpty)
    }

    func testBuildsJsonGetForAnyUrlItIsAskedFor() throws {
        // given
        let spy = ConfigMirrorFetchOperationFactorySpy(probeUrl: probeUrl, probeTimeout: Settings.probeTimeout)
        let factory = BaseFetchOperationFactory(mirrorFetchFactory: spy)

        // when
        let operation: BaseOperation<Payload> = factory.createFetchOperation(
            from: gitHubUrl,
            shouldUseCache: false,
            timeout: Settings.timeout
        )

        // then
        XCTAssertNotNil(operation)

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
            XCTAssertEqual(
                builtRequest.value(forHTTPHeaderField: HttpHeaderKey.contentType.rawValue),
                HttpContentType.json.rawValue
            )
        }
    }

    func testBuildsCachingRequestWithoutTimeoutByDefault() throws {
        // given
        let spy = ConfigMirrorFetchOperationFactorySpy(probeUrl: probeUrl, probeTimeout: nil)
        let factory = BaseFetchOperationFactory(mirrorFetchFactory: spy)

        // when
        let operation: BaseOperation<Payload> = factory.createFetchOperation(from: gitHubUrl)

        // then
        XCTAssertNotNil(operation)

        let call = try XCTUnwrap(spy.calls.first)
        let request = try XCTUnwrap(call.request)
        let plainRequest = URLRequest(url: gitHubUrl)

        XCTAssertNil(call.timeout)
        XCTAssertEqual(request.timeoutInterval, plainRequest.timeoutInterval)
        XCTAssertEqual(request.cachePolicy, plainRequest.cachePolicy)
    }

    func testReportsDecodingFailure() {
        // given
        let spy = ConfigMirrorFetchOperationFactorySpy(probeUrl: probeUrl, probeTimeout: nil)
        spy.responseData = Data("[]".utf8)

        let factory = BaseFetchOperationFactory(mirrorFetchFactory: spy)

        // when
        let operation: BaseOperation<Payload> = factory.createFetchOperation(from: gitHubUrl)

        // then
        XCTAssertThrowsError(try run(operation)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testOperationDoesNotKeepFactoryAlive() {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))

        var factory: BaseFetchOperationFactory? = BaseFetchOperationFactory(mirrorFetchFactory: makeFactory())
        weak var weakFactory = factory

        let operation: BaseOperation<Payload>? = factory?.createFetchOperation(from: gitHubUrl)

        // when
        factory = nil

        // then
        XCTAssertNil(weakFactory)
        XCTAssertEqual(try operation.map { try run($0) }, Payload(source: "mirror"))
    }

    func testSubclassWithOwnInitializerStillFetches() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(otherUrl, with: .response(statusCode: 200, body: gitHubBody))

        let factory = Subclass(name: "subclass")

        // when
        let payload: Payload = try run(factory.createFetchOperation(from: otherUrl))

        // then
        XCTAssertEqual(payload, Payload(source: "github"))
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [otherUrl.absoluteString])
    }

    // MARK: Together with the mirror fetch

    func testReadsMirrorFirst() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        let factory = BaseFetchOperationFactory(mirrorFetchFactory: makeFactory())

        // when
        let payload: Payload = try run(factory.createFetchOperation(from: gitHubUrl))

        // then
        XCTAssertEqual(payload, Payload(source: "mirror"))
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
    }

    func testReadsGitHubWhenMirrorBodyCanNotBeDecoded() throws {
        for body in [Data("<html>".utf8), Data(#"{"other":1}"#.utf8), Data()] {
            resetStubs()

            // given
            ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: body))
            ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

            let factory = BaseFetchOperationFactory(mirrorFetchFactory: makeFactory())

            // when
            let payload: Payload = try run(factory.createFetchOperation(from: gitHubUrl))

            // then
            XCTAssertEqual(payload, Payload(source: "github"))
            XCTAssertEqual(
                ConfigMirrorStubURLProtocol.requestedUrls,
                [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
            )
        }
    }

    func testKeepsRequestSettingsForBothAttemptsAndSplitsTimeout() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 503, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        let factory = BaseFetchOperationFactory(mirrorFetchFactory: makeFactory())

        // when
        let payload: Payload = try run(
            factory.createFetchOperation(from: gitHubUrl, shouldUseCache: false, timeout: Settings.timeout)
        )

        // then
        XCTAssertEqual(payload, Payload(source: "github"))

        let requests = ConfigMirrorStubURLProtocol.requests

        XCTAssertEqual(requests.map(\.timeoutInterval), [Settings.timeout / 2, Settings.timeout])
        XCTAssertEqual(
            requests.map(\.cachePolicy),
            [.reloadIgnoringLocalAndRemoteCacheData, .reloadIgnoringLocalAndRemoteCacheData]
        )
        XCTAssertEqual(
            requests.map { $0.value(forHTTPHeaderField: HttpHeaderKey.contentType.rawValue) },
            [HttpContentType.json.rawValue, HttpContentType.json.rawValue]
        )
    }

    func testReportsGitHubFailureWhenBothFail() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 500, body: Data()))

        let factory = BaseFetchOperationFactory(mirrorFetchFactory: makeFactory())
        let operation: BaseOperation<Payload> = factory.createFetchOperation(from: gitHubUrl)

        // when
        XCTAssertThrowsError(try run(operation)) { error in
            // then
            XCTAssertEqual(error as? NetworkResponseError, .internalServerError)
        }
    }
}
