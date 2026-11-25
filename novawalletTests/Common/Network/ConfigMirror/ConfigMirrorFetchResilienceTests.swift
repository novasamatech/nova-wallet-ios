import XCTest
import Operation_iOS
@testable import novawallet

/// A mirror answer with an unusable body, the cool-down after an unreachable mirror and what gets logged
final class ConfigMirrorFetchResilienceTests: ConfigMirrorFetchTestCase {
    private let gitHubIconUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/icons/DOT.svg")!
    private let mirrorIconUrl = URL(string: "https://mirror.novatest/v1/config/icons/DOT.svg")!
    private let gitHubTypesUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/chains/types/default.json")!
    private let mirrorTypesUrl = URL(string: "https://mirror.novatest/v1/config/chains/types/default.json")!

    // MARK: Body validation

    func testFallsBackToGitHubWhenMirrorBodyIsEmpty() throws {
        try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: 200, body: Data()))

        XCTAssertTrue(logger.warnings.first?.contains("emptyBody") ?? false)
    }

    func testFallsBackToGitHubWhenMirrorJsonIsTruncated() throws {
        try assertFallsBackToGitHub(
            whenMirrorAnswers: .response(statusCode: 200, body: Data(#"[{"chainId":"91b171bb158e2d38"#.utf8))
        )

        XCTAssertTrue(logger.warnings.first?.contains("malformedJson") ?? false)
    }

    func testFallsBackToGitHubWhenMirrorAnswersHtmlForJson() throws {
        try assertFallsBackToGitHub(
            whenMirrorAnswers: .response(statusCode: 200, body: Data("<html><body>Bad gateway</body></html>".utf8))
        )
    }

    func testValidatesJsonWhateverTheCaseOfExtension() throws {
        let gitHubUrl = try XCTUnwrap(
            URL(string: "https://github.novatest/novasamatech/nova-utils/master/chains/v23/CHAINS.JSON")
        )
        let mirrorUrl = try XCTUnwrap(URL(string: "https://mirror.novatest/v1/config/chains/v23/CHAINS.JSON"))

        try assertFallsBackToGitHub(
            whenMirrorAnswers: .response(statusCode: 200, body: Data("not json".utf8)),
            from: gitHubUrl,
            mirrorUrl: mirrorUrl
        )
    }

    func testAcceptsJsonArrayAndObjectFromMirror() throws {
        for body in [#"[{"chainId":"91b1"}]"#, #"{"types":{}}"#, " \n[]\n"] {
            resetStubs()

            ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: Data(body.utf8)))

            XCTAssertEqual(try fetch(gitHubUrl), Data(body.utf8))
            XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
        }
    }

    func testAcceptsAnyNotEmptyBodyOfNotJsonFile() throws {
        // given
        let svg = Data("<svg/>".utf8)

        ConfigMirrorStubURLProtocol.stub(mirrorIconUrl, with: .response(statusCode: 200, body: svg))

        // when
        let data = try fetch(gitHubIconUrl)

        // then
        XCTAssertEqual(data, svg)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorIconUrl.absoluteString])
    }

    func testFallsBackToGitHubWhenNotJsonFileIsEmpty() throws {
        try assertFallsBackToGitHub(
            whenMirrorAnswers: .response(statusCode: 200, body: Data()),
            from: gitHubIconUrl,
            mirrorUrl: mirrorIconUrl
        )
    }

    func testGitHubBodyIsReturnedAsIsEvenIfUnusable() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: Data("not json".utf8)))

        // when
        let data = try fetch(gitHubUrl)

        // then
        XCTAssertEqual(data, Data("not json".utf8))
    }

    func testProcessesMirrorAnswerOffTheMainThread() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))

        var processedOnMainThread: Bool?

        let resultFactory = AnyNetworkResultFactory<Data> { data in
            processedOnMainThread = Thread.isMainThread
            return data
        }

        let operation = makeFactory().createFetchOperation(
            from: gitHubUrl,
            timeout: nil,
            resultFactory: resultFactory
        ) { requestUrl, _ in
            BlockNetworkRequestFactory { URLRequest(url: requestUrl) }
        }

        // when
        _ = try run(operation)

        // then
        XCTAssertEqual(processedOnMainThread, false)
    }

    // MARK: Cool-down

    func testSkipsMirrorAfterItCouldNotBeReached() throws {
        // given
        try assertFallsBackToGitHub(whenMirrorAnswers: .failure(.cannotConnectToHost))

        resetStubs()

        ConfigMirrorStubURLProtocol.stub(mirrorTypesUrl, with: .response(statusCode: 200, body: mirrorBody))
        ConfigMirrorStubURLProtocol.stub(gitHubTypesUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let operation = makeOperation(for: gitHubTypesUrl, timeout: Constants.callerTimeout)
        let data = try run(operation)

        // then
        XCTAssertTrue(operation is NetworkOperation<Data>)
        XCTAssertEqual(data, gitHubBody)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [gitHubTypesUrl.absoluteString])
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requests.first?.timeoutInterval, Constants.callerTimeout)
    }

    func testSkipsMirrorAfterItTimedOut() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .hanging)
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        XCTAssertEqual(try fetch(gitHubUrl, mirrorTimeout: 0.5), gitHubBody)

        resetStubs()

        ConfigMirrorStubURLProtocol.stub(gitHubTypesUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let data = try fetch(gitHubTypesUrl)

        // then
        XCTAssertEqual(data, gitHubBody)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [gitHubTypesUrl.absoluteString])
    }

    func testTriesMirrorAgainWhenCooldownEnds() throws {
        // given
        try assertFallsBackToGitHub(whenMirrorAnswers: .failure(.timedOut))

        resetStubs()

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        clock.advance(by: Constants.cooldown - 1)

        XCTAssertEqual(try fetch(gitHubUrl), gitHubBody)

        // when
        clock.advance(by: 1)

        // then
        XCTAssertEqual(try fetch(gitHubUrl), mirrorBody)
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [gitHubUrl.absoluteString, mirrorUrl.absoluteString]
        )
    }

    func testKeepsTryingMirrorAfterStatusAndBodyFailures() throws {
        // given
        try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: 404, body: Data()))

        resetStubs()

        try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: 503, body: Data()))

        resetStubs()

        try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: 200, body: Data()))

        resetStubs()

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))

        // when
        let data = try fetch(gitHubUrl)

        // then
        XCTAssertEqual(data, mirrorBody)
        XCTAssertTrue(availability.isAvailable)
    }

    // MARK: Logging

    func testLogsMirrorFailureWithFilePathAndError() throws {
        // when
        try assertFallsBackToGitHub(whenMirrorAnswers: .response(statusCode: 404, body: Data()))

        // then
        let warnings = logger.warnings

        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(logger.warning(at: 0).contains("/v1/config/chains/v23/chains.json"))
        XCTAssertTrue(logger.warning(at: 0).contains("resourceNotFound"))
        XCTAssertTrue(logger.otherMessages.isEmpty)
    }

    func testLogsCooldownStartOnce() throws {
        // when
        try assertFallsBackToGitHub(whenMirrorAnswers: .failure(.timedOut))

        // then
        let warnings = logger.warnings

        XCTAssertEqual(warnings.count, 2)
        XCTAssertTrue(logger.warning(at: 0).contains("/v1/config/chains/v23/chains.json"))
        XCTAssertTrue(logger.warning(at: 1).contains("cool-down"))

        // when
        resetStubs()

        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        _ = try fetch(gitHubUrl)

        // then
        XCTAssertEqual(logger.warnings.count, 2)
    }
}
