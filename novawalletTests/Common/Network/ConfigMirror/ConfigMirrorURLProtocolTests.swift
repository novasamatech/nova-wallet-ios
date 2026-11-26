import XCTest
@testable import novawallet

final class ConfigMirrorURLProtocolTests: XCTestCase {
    private let gitHubUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/chains/v23/chains.json")!
    private let mirrorUrl = URL(string: "https://mirror.novatest/v1/config/chains/v23/chains.json")!
    private let gitHubIconUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/icons/DOT.png")!
    private let mirrorIconUrl = URL(string: "https://mirror.novatest/v1/config/icons/DOT.png")!
    private let otherUrl = URL(string: "https://github.novatest/novasamatech/branding/master/logo.png")!

    private let mirrorBody = Data(#"{"source":"mirror"}"#.utf8)
    private let gitHubBody = Data(#"{"source":"github"}"#.utf8)
    private let initialPause: TimeInterval = 60
    private let attemptDeadline: TimeInterval = 10

    private var clock: ConfigMirrorTestClock!
    private var availability: ConfigMirrorAvailabilitySpy!
    private var loader: ConfigMirrorFakeLoader!
    private var logger: ConfigMirrorLoggerSpy!
    private var client: ConfigMirrorClientSpy!
    private var schedulers: [ConfigMirrorFakeScheduler] = []

    // the system keeps a protocol alive while it loads, here the test has to
    private var startedProtocols: [ConfigMirrorURLProtocol] = []

    override func setUp() {
        super.setUp()

        setUpDependencies()
    }

    override func tearDown() {
        ConfigMirrorURLProtocol.unregister()

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

    func testHandlesNothingUntilRegisteredAndAfterUnregistered() {
        ConfigMirrorURLProtocol.unregister()

        XCTAssertNil(ConfigMirrorURLProtocol.dependencies)
        XCTAssertFalse(ConfigMirrorURLProtocol.canInit(with: URLRequest(url: gitHubUrl)))
    }

    func testHandsOverMirrorAnswerForOriginalUrlOnlyWhenItIsCompleteAndChecked() {
        let answers: [(gitHubUrl: URL, mirrorUrl: URL, chunks: [String])] = [
            (gitHubUrl, mirrorUrl, [#"{"source":"#, #""mirror"}"#]),
            (gitHubIconUrl, mirrorIconUrl, ["png ", "bytes"])
        ]

        for answer in answers {
            setUpDependencies()

            start(URLRequest(url: answer.gitHubUrl))
            loader.send([response(200, answer.mirrorUrl)] + answer.chunks.map { .data(Data($0.utf8)) }, toRequest: 0)

            // whatever the file is, nothing reaches the caller while the mirror can still fail
            XCTAssertTrue(client.events.isEmpty, answer.mirrorUrl.path)

            loader.send([.completed(nil)], toRequest: 0)

            XCTAssertEqual(
                client.events,
                [
                    "response 200 \(answer.gitHubUrl.absoluteString) stored=false",
                    "data \(answer.chunks.joined())",
                    "finished"
                ],
                answer.mirrorUrl.path
            )
            XCTAssertEqual(loader.requestedUrls, [answer.mirrorUrl.absoluteString], answer.mirrorUrl.path)
            XCTAssertEqual(availability.endedAttempts, ["regular reachable"], answer.mirrorUrl.path)
            XCTAssertTrue(logger.warnings.isEmpty, answer.mirrorUrl.path)
            XCTAssertEqual(schedulers.map(\.isCancelled), [true], answer.mirrorUrl.path)
        }
    }

    func testFallsBackToOriginalUrlWhenMirrorAnswerIsUnusable() {
        let cases: [(name: String, events: [ConfigMirrorLoadEvent], verdict: ConfigMirrorAttemptVerdict)] = [
            ("no file", [response(404, mirrorUrl, headers: nil), .data(Data("{}".utf8)), .completed(nil)], .reachable),
            ("bad request", [response(400, mirrorUrl, headers: nil), .completed(nil)], .reachable),
            ("limit", [response(429, mirrorUrl, headers: nil), .completed(nil)], .unavailable),
            ("not ready", [response(503, mirrorUrl, headers: nil), .completed(nil)], .unavailable),
            ("server error", [response(500, mirrorUrl, headers: nil), .data(mirrorBody), .completed(nil)], .unavailable),
            ("other success status", [response(204, mirrorUrl), .data(mirrorBody), .completed(nil)], .reachable),
            ("redirect", [response(302, mirrorUrl, headers: ["Location": "https://x.novatest/"]), .completed(nil)], .reachable),
            ("page of a network on the way", [response(200, mirrorUrl, headers: nil), .data(mirrorBody), .completed(nil)], .reachable),
            ("empty body", [response(200, mirrorUrl), .completed(nil)], .reachable),
            ("truncated json", [response(200, mirrorUrl), .data(Data(#"[{"chainId":"#.utf8)), .completed(nil)], .reachable),
            ("html for json", [response(200, mirrorUrl), .data(Data("<html></html>".utf8)), .completed(nil)], .reachable),
            ("broken off", [response(200, mirrorUrl), .data(mirrorBody), .completed(URLError(.networkConnectionLost))], .unavailable),
            ("unreachable", [.completed(URLError(.cannotConnectToHost))], .unavailable),
            ("timeout", [.completed(URLError(.timedOut))], .unavailable),
            ("tls", [.completed(URLError(.secureConnectionFailed))], .unavailable),
            ("no internet", [.completed(URLError(.notConnectedToInternet))], .unknown),
            ("unusable answer of http cache", [response(200, mirrorUrl), .servedFromLocalCache, .completed(nil)], .unknown)
        ]

        for testCase in cases {
            setUpDependencies()

            start(URLRequest(url: gitHubUrl))
            loader.send(testCase.events, toRequest: 0)

            XCTAssertTrue(client.events.isEmpty, testCase.name)
            XCTAssertEqual(loader.requestedUrls, [mirrorUrl.absoluteString, gitHubUrl.absoluteString], testCase.name)

            loader.send([response(200, gitHubUrl, headers: nil), .data(gitHubBody), .completed(nil)], toRequest: 1)

            let startsPause = testCase.verdict == .unavailable

            XCTAssertEqual(
                client.events,
                ["response 200 \(gitHubUrl.absoluteString) stored=false", #"data {"source":"github"}"#, "finished"],
                testCase.name
            )
            XCTAssertEqual(availability.endedAttempts, ["regular \(testCase.verdict)"], testCase.name)
            XCTAssertEqual(availability.beginAttempt() == nil, startsPause, testCase.name)
            XCTAssertEqual(logger.warnings.count, startsPause ? 2 : 1, testCase.name)
            XCTAssertTrue(logger.warnings.first?.contains("/v1/config/chains/v23/chains.json") ?? false, testCase.name)
            XCTAssertEqual(schedulers.map(\.isCancelled), [true], testCase.name)
        }
    }

    func testFallsBackToOriginalUrlWhenMirrorAttemptOutlastsItsDeadline() {
        // the mirror keeps sending a json that never ends
        start(URLRequest(url: gitHubUrl))
        loader.send([response(200, mirrorUrl), .data(Data(#"{"source":"#.utf8))], toRequest: 0)

        XCTAssertEqual(schedulers.map(\.delay), [attemptDeadline])

        schedulers[0].trigger()

        XCTAssertEqual(loader.cancelledRequests, [0])
        XCTAssertEqual(loader.requestedUrls, [mirrorUrl.absoluteString, gitHubUrl.absoluteString])
        XCTAssertEqual(availability.endedAttempts, ["regular unavailable"])
        XCTAssertEqual(logger.warnings.count, 2)
        XCTAssertTrue(logger.warnings.last?.contains("60 s") ?? false)

        // what the cancelled attempt still reports is not taken for the answer
        loader.send([.data(Data(#""mirror"}"#.utf8)), .completed(URLError(.cancelled))], toRequest: 0)

        XCTAssertTrue(client.events.isEmpty)
        XCTAssertEqual(loader.requests.count, 2)

        loader.send([response(200, gitHubUrl, headers: nil), .data(gitHubBody), .completed(nil)], toRequest: 1)

        XCTAssertEqual(
            client.events,
            ["response 200 \(gitHubUrl.absoluteString) stored=false", #"data {"source":"github"}"#, "finished"]
        )
        XCTAssertEqual(availability.endedAttempts.count, 1)
    }

    func testDeadlineThatComesAfterAttemptIsOverChangesNothing() {
        start(URLRequest(url: gitHubUrl))
        loader.send([response(200, mirrorUrl), .data(mirrorBody), .completed(nil)], toRequest: 0)

        let eventCount = client.events.count

        schedulers[0].trigger()

        XCTAssertEqual(client.events.count, eventCount)
        XCTAssertEqual(loader.requests.count, 1)
        XCTAssertTrue(loader.cancelledRequests.isEmpty)
        XCTAssertEqual(availability.endedAttempts, ["regular reachable"])
    }

    func testHandsFailureOfOriginalUrlToClientAsItIs() {
        start(URLRequest(url: gitHubUrl))
        loader.send([response(404, mirrorUrl, headers: nil), .completed(nil)], toRequest: 0)
        loader.send([response(500, gitHubUrl, headers: nil), .completed(URLError(.networkConnectionLost))], toRequest: 1)

        XCTAssertEqual(
            client.events,
            ["response 500 \(gitHubUrl.absoluteString) stored=false", "failed \(URLError.Code.networkConnectionLost.rawValue)"]
        )
    }

    func testOriginalUrlIsStreamedAndLoadedByCallersRules() {
        start(URLRequest(url: gitHubUrl))
        loader.send([response(404, mirrorUrl, headers: nil), .completed(nil)], toRequest: 0)
        loader.send([response(200, gitHubUrl, headers: nil), .data(Data("a".utf8))], toRequest: 1)

        XCTAssertEqual(client.events, ["response 200 \(gitHubUrl.absoluteString) stored=false", "data a"])

        // the mirror is not followed anywhere else and only its usable answer is kept in the http cache
        XCTAssertEqual(loader.rules.map(\.followsRedirects), [false, true])
        XCTAssertNil(loader.rules.last?.storageCondition)

        let storageCondition = loader.rules.first?.storageCondition

        XCTAssertEqual(storageCondition?(ConfigMirrorTestAnswer.response(200, mirrorUrl), mirrorBody), true)
        XCTAssertEqual(storageCondition?(ConfigMirrorTestAnswer.response(200, mirrorUrl), Data("<html>".utf8)), false)
        XCTAssertEqual(storageCondition?(ConfigMirrorTestAnswer.response(200, mirrorUrl, headers: nil), mirrorBody), false)
    }

    func testSkipsMirrorDuringPauseAndProbesItWithSingleRequestAfterwards() {
        // given
        start(URLRequest(url: gitHubUrl))
        loader.send([.completed(URLError(.timedOut))], toRequest: 0)

        XCTAssertEqual(loader.requestedUrls, [mirrorUrl.absoluteString, gitHubUrl.absoluteString])

        // when
        start(URLRequest(url: gitHubUrl))

        clock.time += initialPause

        start(URLRequest(url: gitHubUrl))
        start(URLRequest(url: gitHubUrl))

        // then
        let afterPauseUrls = [gitHubUrl.absoluteString, mirrorUrl.absoluteString, gitHubUrl.absoluteString]

        XCTAssertEqual(Array(loader.requestedUrls.dropFirst(2)), afterPauseUrls)
        XCTAssertEqual(availability.begunAttempts, [.regular, nil, .probe, nil])

        // an answer about one file is an answer of the mirror: it is in use again
        loader.send([response(404, mirrorUrl, headers: nil), .completed(nil)], toRequest: 3)
        start(URLRequest(url: gitHubUrl))

        XCTAssertEqual(availability.endedAttempts, ["regular unavailable", "probe reachable"])
        XCTAssertEqual(loader.requestedUrls.last, mirrorUrl.absoluteString)
    }

    func testProbeThatLearnsNothingLeavesItsSlotToNextRequest() {
        let endings: [(name: String, finish: (ConfigMirrorURLProtocol) -> Void)] = [
            ("cancelled by caller", { $0.stopLoading() }),
            ("answered by http cache", { [self] _ in
                loader.send([response(200, mirrorUrl), .data(mirrorBody), .servedFromLocalCache, .completed(nil)], toRequest: 2)
            }),
            ("device is offline", { [self] _ in
                loader.send([.completed(URLError(.notConnectedToInternet))], toRequest: 2)
            })
        ]

        for ending in endings {
            setUpDependencies()

            start(URLRequest(url: gitHubUrl))
            loader.send([.completed(URLError(.timedOut))], toRequest: 0)

            clock.time += initialPause

            let probe = start(URLRequest(url: gitHubUrl))
            ending.finish(probe)

            start(URLRequest(url: gitHubUrl))

            XCTAssertEqual(availability.begunAttempts, [.regular, .probe, .probe], ending.name)
            XCTAssertEqual(availability.endedAttempts, ["regular unavailable", "probe unknown"], ending.name)
        }
    }

    func testFailedProbeStartsLongerPause() {
        start(URLRequest(url: gitHubUrl))
        loader.send([.completed(URLError(.timedOut))], toRequest: 0)

        clock.time += initialPause

        start(URLRequest(url: gitHubUrl))
        schedulers.last?.trigger()

        XCTAssertEqual(availability.endedAttempts, ["regular unavailable", "probe unavailable"])
        XCTAssertTrue(logger.warnings.last?.contains("120 s") ?? false)

        clock.time += initialPause

        XCTAssertNil(availability.beginAttempt())

        clock.time += initialPause

        XCTAssertEqual(availability.beginAttempt(), .probe)
    }

    func testMirrorAttemptIsBoundedByDeadlineAndHalfOfCallersTimeoutAndOriginalRequestStaysAsItWas() throws {
        for (requestTimeout, mirrorTimeout) in [(60.0, 10.0), (30, 10), (20, 10), (15, 7.5), (6, 3)] {
            setUpDependencies()

            var request = URLRequest(url: gitHubUrl, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: requestTimeout)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            start(request)

            XCTAssertEqual(schedulers.map(\.delay), [mirrorTimeout])

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
        XCTAssertEqual(schedulers.map(\.isCancelled), [true])

        // during the attempt for the original url
        let originalAttempt = start(URLRequest(url: gitHubUrl))
        loader.send([response(404, mirrorUrl, headers: nil), .completed(nil)], toRequest: 1)
        originalAttempt.stopLoading()
        loader.send([response(200, gitHubUrl, headers: nil), .data(gitHubBody), .completed(nil)], toRequest: 2)

        XCTAssertEqual(loader.cancelledRequests, [0, 2])
        XCTAssertTrue(client.events.isEmpty)
        XCTAssertEqual(availability.endedAttempts, ["regular unknown", "regular reachable"])
        XCTAssertEqual(availability.beginAttempt(), .regular)
        XCTAssertEqual(logger.warnings.count, 1)
    }
}

private extension ConfigMirrorURLProtocolTests {
    func setUpDependencies() {
        let clock = ConfigMirrorTestClock()

        self.clock = clock
        availability = ConfigMirrorAvailabilitySpy(
            availability: ConfigMirrorAvailability(initialPause: initialPause) { clock.time }
        )
        loader = ConfigMirrorFakeLoader()
        logger = ConfigMirrorLoggerSpy()
        schedulers = []

        let dependencies = ConfigMirrorURLProtocol.Dependencies(
            urlResolver: ConfigMirrorURLResolver(
                mirrorBaseURL: URL(string: "https://mirror.novatest/v1/config/")!,
                sources: [URL(string: "https://github.novatest/novasamatech/nova-utils/master/")!]
            ),
            availability: availability,
            loader: loader,
            logger: logger,
            attemptDeadline: attemptDeadline,
            schedulerClosure: { [weak self] delegate in
                let scheduler = ConfigMirrorFakeScheduler(delegate: delegate)
                self?.schedulers.append(scheduler)

                return scheduler
            }
        )

        ConfigMirrorURLProtocol.unregister()
        ConfigMirrorURLProtocol.register(dependencies: dependencies)
    }

    @discardableResult
    func start(_ request: URLRequest) -> ConfigMirrorURLProtocol {
        client = ConfigMirrorClientSpy()

        let urlProtocol = ConfigMirrorURLProtocol(request: request, cachedResponse: nil, client: client)
        startedProtocols.append(urlProtocol)
        urlProtocol.startLoading()

        return urlProtocol
    }

    func response(
        _ statusCode: Int,
        _ url: URL,
        headers: [String: String]? = ConfigMirrorTestAnswer.commitHeaders
    ) -> ConfigMirrorLoadEvent {
        .response(ConfigMirrorTestAnswer.response(statusCode, url, headers: headers))
    }
}
