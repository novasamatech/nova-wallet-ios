import XCTest
@testable import novawallet

final class ConfigMirrorURLProtocolTests: XCTestCase {
    private let gitHubUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/chains/v23/chains.json")!
    private let mirrorUrl = URL(string: "https://mirror.novatest/v1/config/chains/v23/chains.json")!
    private let gitHubIconUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/icons/DOT.png")!
    private let otherUrl = URL(string: "https://github.novatest/novasamatech/branding/master/logo.png")!

    private let mirrorBody = Data(#"{"source":"mirror"}"#.utf8)
    private let gitHubBody = Data(#"{"source":"github"}"#.utf8)
    private let cooldown: TimeInterval = 60

    private var savedDependencies: ConfigMirrorURLProtocol.Dependencies!
    private var clock: ConfigMirrorTestClock!
    private var availability: ConfigMirrorAvailability!
    private var loader: ConfigMirrorFakeLoader!
    private var logger: ConfigMirrorLoggerSpy!
    private var client: ConfigMirrorClientSpy!

    // the system keeps a protocol alive while it loads, here the test has to
    private var startedProtocols: [ConfigMirrorURLProtocol] = []

    override func setUp() {
        super.setUp()

        savedDependencies = ConfigMirrorURLProtocol.dependencies
        setUpDependencies()
    }

    override func tearDown() {
        ConfigMirrorURLProtocol.dependencies = savedDependencies

        super.tearDown()
    }

    func testHandlesOnlyGetRequestsOfMirroredUrlsOnce() throws {
        var postRequest = URLRequest(url: gitHubUrl)
        postRequest.httpMethod = "POST"

        XCTAssertTrue(ConfigMirrorURLProtocol.canInit(with: URLRequest(url: gitHubUrl)))
        XCTAssertFalse(ConfigMirrorURLProtocol.canInit(with: postRequest))
        XCTAssertFalse(ConfigMirrorURLProtocol.canInit(with: URLRequest(url: otherUrl)))
        XCTAssertFalse(ConfigMirrorURLProtocol.canInit(with: URLRequest(url: mirrorUrl)))

        // the requests the protocol makes itself must not come back to it
        start(URLRequest(url: gitHubUrl))
        loader.send([.completed(URLError(.timedOut))], toRequest: 0)

        for request in loader.requests {
            XCTAssertFalse(ConfigMirrorURLProtocol.canInit(with: request))
        }

        XCTAssertEqual(loader.requestedUrls, [mirrorUrl.absoluteString, gitHubUrl.absoluteString])
    }

    func testAnswersWithMirrorBodyForOriginalUrl() {
        start(URLRequest(url: gitHubUrl))
        loader.send([response(200, mirrorUrl), .data(mirrorBody)], toRequest: 0)

        // a json is held back until it is complete and checked
        XCTAssertTrue(client.events.isEmpty)

        loader.send([.completed(nil)], toRequest: 0)

        XCTAssertEqual(
            client.events,
            ["response 200 \(gitHubUrl.absoluteString) stored=false", #"data {"source":"mirror"}"#, "finished"]
        )
        XCTAssertEqual(loader.requestedUrls, [mirrorUrl.absoluteString])
        XCTAssertTrue(logger.warnings.isEmpty)
    }

    func testFallsBackToOriginalUrlWhenMirrorAnswerIsUnusable() {
        let cases: [(name: String, events: [ConfigMirrorLoadEvent], startsCooldown: Bool)] = [
            ("no file", [response(404, mirrorUrl), .data(Data("{}".utf8)), .completed(nil)], false),
            ("not ready", [response(503, mirrorUrl), .completed(nil)], false),
            ("other success status", [response(204, mirrorUrl), .data(mirrorBody), .completed(nil)], false),
            ("empty body", [response(200, mirrorUrl), .completed(nil)], false),
            ("truncated json", [response(200, mirrorUrl), .data(Data(#"[{"chainId":"#.utf8)), .completed(nil)], false),
            ("html for json", [response(200, mirrorUrl), .data(Data("<html></html>".utf8)), .completed(nil)], false),
            ("broken off", [response(200, mirrorUrl), .data(mirrorBody), .completed(URLError(.networkConnectionLost))], true),
            ("unreachable", [.completed(URLError(.cannotConnectToHost))], true),
            ("timeout", [.completed(URLError(.timedOut))], true),
            ("tls", [.completed(URLError(.secureConnectionFailed))], true)
        ]

        for testCase in cases {
            setUpDependencies()

            start(URLRequest(url: gitHubUrl))
            loader.send(testCase.events, toRequest: 0)

            XCTAssertTrue(client.events.isEmpty, testCase.name)
            XCTAssertEqual(loader.requestedUrls, [mirrorUrl.absoluteString, gitHubUrl.absoluteString], testCase.name)

            loader.send([response(200, gitHubUrl), .data(gitHubBody), .completed(nil)], toRequest: 1)

            XCTAssertEqual(
                client.events,
                ["response 200 \(gitHubUrl.absoluteString) stored=false", #"data {"source":"github"}"#, "finished"],
                testCase.name
            )
            XCTAssertEqual(availability.isAvailable, !testCase.startsCooldown, testCase.name)
            XCTAssertEqual(logger.warnings.count, testCase.startsCooldown ? 2 : 1, testCase.name)
            XCTAssertTrue(logger.warnings.first?.contains("/v1/config/chains/v23/chains.json") ?? false, testCase.name)
        }
    }

    func testHandsFailureOfOriginalUrlToClientAsItIs() {
        start(URLRequest(url: gitHubUrl))
        loader.send([response(404, mirrorUrl), .completed(nil)], toRequest: 0)
        loader.send([response(500, gitHubUrl), .completed(URLError(.networkConnectionLost))], toRequest: 1)

        XCTAssertEqual(
            client.events,
            ["response 500 \(gitHubUrl.absoluteString) stored=false", "failed \(URLError.Code.networkConnectionLost.rawValue)"]
        )
    }

    func testSkipsMirrorDuringCooldown() {
        XCTAssertTrue(availability.registerFailure(URLError(.timedOut)))

        start(URLRequest(url: gitHubUrl))

        XCTAssertEqual(loader.requestedUrls, [gitHubUrl.absoluteString])
        XCTAssertTrue(logger.warnings.isEmpty)

        clock.uptime += cooldown
        start(URLRequest(url: gitHubUrl))

        XCTAssertEqual(loader.requestedUrls.last, mirrorUrl.absoluteString)
    }

    func testMirrorGetsShortTimeoutAndOriginalRequestStaysAsItWas() throws {
        for (requestTimeout, mirrorTimeout) in [(60.0, 5.0), (15, 5), (10, 5), (6, 3)] {
            setUpDependencies()

            var request = URLRequest(url: gitHubUrl, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: requestTimeout)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            start(request)
            loader.send([.completed(URLError(.timedOut))], toRequest: 0)

            let requests = loader.requests

            XCTAssertEqual(requests.map(\.timeoutInterval), [mirrorTimeout, requestTimeout])
            XCTAssertEqual(requests.map(\.cachePolicy), [request.cachePolicy, request.cachePolicy])
            XCTAssertEqual(requests.map(\.httpMethod), [request.httpMethod, request.httpMethod])
            XCTAssertEqual(requests.map(\.allHTTPHeaderFields), [request.allHTTPHeaderFields, request.allHTTPHeaderFields])
        }
    }

    func testStopCancelsCurrentAttemptAndNothingFollows() {
        // during the mirror attempt
        let mirrorAttempt = start(URLRequest(url: gitHubUrl))
        mirrorAttempt.stopLoading()
        loader.send([.completed(URLError(.cancelled))], toRequest: 0)

        XCTAssertEqual(loader.cancelledRequests, [0])

        // during the attempt for the original url
        let originalAttempt = start(URLRequest(url: gitHubUrl))
        loader.send([response(404, mirrorUrl), .completed(nil)], toRequest: 1)
        originalAttempt.stopLoading()
        loader.send([response(200, gitHubUrl), .data(gitHubBody), .completed(nil)], toRequest: 2)

        XCTAssertEqual(loader.cancelledRequests, [0, 2])
        XCTAssertTrue(client.events.isEmpty)
        XCTAssertTrue(availability.isAvailable)
        XCTAssertEqual(logger.warnings.count, 1)
    }

    func testPassesOnNotJsonMirrorBodyAsItArrives() {
        let mirrorIconUrl = URL(string: "https://mirror.novatest/v1/config/icons/DOT.png")!

        start(URLRequest(url: gitHubIconUrl))
        loader.send([response(200, mirrorIconUrl), .data(Data("a".utf8))], toRequest: 0)

        XCTAssertEqual(client.events, ["response 200 \(gitHubIconUrl.absoluteString) stored=false", "data a"])

        loader.send([.data(Data("b".utf8)), .completed(nil)], toRequest: 0)

        XCTAssertEqual(client.events.suffix(2), ["data b", "finished"])

        // once a part of the body is handed over there is no way back to the original url
        start(URLRequest(url: gitHubIconUrl))
        loader.send([response(200, mirrorIconUrl), .data(Data("a".utf8)), .completed(URLError(.timedOut))], toRequest: 1)

        XCTAssertEqual(client.events.last, "failed \(URLError.Code.timedOut.rawValue)")
        XCTAssertEqual(loader.requests.count, 2)
    }
}

private extension ConfigMirrorURLProtocolTests {
    func setUpDependencies() {
        let clock = ConfigMirrorTestClock()

        self.clock = clock
        availability = ConfigMirrorAvailability(cooldown: cooldown) { clock.uptime }
        loader = ConfigMirrorFakeLoader()
        logger = ConfigMirrorLoggerSpy()

        ConfigMirrorURLProtocol.dependencies = ConfigMirrorURLProtocol.Dependencies(
            urlResolver: ConfigMirrorURLResolver(
                mirrorBaseURL: URL(string: "https://mirror.novatest/v1/config/")!,
                sources: ["github.novatest/novasamatech/nova-utils/master/"]
            ),
            availability: availability,
            loader: loader,
            mirrorTimeout: 5,
            logger: logger
        )
    }

    @discardableResult
    func start(_ request: URLRequest) -> ConfigMirrorURLProtocol {
        client = ConfigMirrorClientSpy()

        let urlProtocol = ConfigMirrorURLProtocol(request: request, cachedResponse: nil, client: client)
        startedProtocols.append(urlProtocol)
        urlProtocol.startLoading()

        return urlProtocol
    }

    func response(_ statusCode: Int, _ url: URL) -> ConfigMirrorLoadEvent {
        .response(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!)
    }
}
