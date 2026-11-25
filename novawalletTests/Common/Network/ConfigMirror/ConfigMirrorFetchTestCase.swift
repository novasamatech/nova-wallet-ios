import XCTest
import Operation_iOS
@testable import novawallet

/// Shared setup of the tests that run the mirror-aware fetch against stubbed hosts
class ConfigMirrorFetchTestCase: XCTestCase {
    enum Constants {
        static let mirrorHost = "mirror.novatest"
        static let gitHubHost = "github.novatest"
        static let otherHost = "other.novatest"
        static let callerTimeout: TimeInterval = 30
        static let mirrorTimeout: TimeInterval = 7
        static let cooldown: TimeInterval = 60
        static let expectationTimeout: TimeInterval = 10
    }

    let gitHubUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/chains/v23/chains.json")!
    let mirrorUrl = URL(string: "https://mirror.novatest/v1/config/chains/v23/chains.json")!
    let otherUrl = URL(string: "https://other.novatest/novasamatech/branding/master/logo.png")!

    let mirrorBody = Data(#"{"source":"mirror"}"#.utf8)
    let gitHubBody = Data(#"{"source":"github"}"#.utf8)
    let otherBody = Data("other".utf8)

    let operationQueue = OperationQueue()

    private(set) var clock: ConfigMirrorTestClock!
    private(set) var availability: ConfigMirrorAvailability!
    private(set) var logger: ConfigMirrorLoggerSpy!

    var resolver: ConfigMirrorURLResolver {
        ConfigMirrorURLResolver(
            mirrorBaseURL: URL(string: "https://\(Constants.mirrorHost)/v1/config/")!,
            sources: ["\(Constants.gitHubHost)/novasamatech/nova-utils/master/"]
        )
    }

    override func setUp() {
        super.setUp()

        let clock = ConfigMirrorTestClock()

        self.clock = clock
        availability = ConfigMirrorAvailability(cooldown: Constants.cooldown) { clock.uptime }
        logger = ConfigMirrorLoggerSpy()

        resetStubs()

        XCTAssertTrue(URLProtocol.registerClass(ConfigMirrorStubURLProtocol.self))
    }

    override func tearDown() {
        URLProtocol.unregisterClass(ConfigMirrorStubURLProtocol.self)
        ConfigMirrorStubURLProtocol.reset()

        super.tearDown()
    }

    func resetStubs() {
        ConfigMirrorStubURLProtocol.reset(
            hosts: [Constants.mirrorHost, Constants.gitHubHost, Constants.otherHost]
        )
    }

    func makeFactory(mirrorTimeout: TimeInterval = Constants.mirrorTimeout) -> ConfigMirrorFetchOperationFactory {
        ConfigMirrorFetchOperationFactory(
            urlResolver: resolver,
            availability: availability,
            mirrorTimeout: mirrorTimeout,
            logger: logger
        )
    }

    func makeOperation(
        for url: URL,
        timeout: TimeInterval?,
        mirrorTimeout: TimeInterval = Constants.mirrorTimeout
    ) -> BaseOperation<Data> {
        makeFactory(mirrorTimeout: mirrorTimeout).createFetchOperation(
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

    func run<T>(_ operation: BaseOperation<T>) throws -> T {
        operationQueue.addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }

    func assertFallsBackToGitHub(
        whenMirrorAnswers mirrorStub: ConfigMirrorStubURLProtocol.Stub,
        from gitHubUrl: URL? = nil,
        mirrorUrl: URL? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let gitHubUrl = gitHubUrl ?? self.gitHubUrl
        let mirrorUrl = mirrorUrl ?? self.mirrorUrl

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
