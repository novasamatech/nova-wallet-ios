import XCTest
import Operation_iOS
@testable import novawallet

final class BaseFetchOperationFactoryTests: XCTestCase {
    struct Payload: Decodable, Equatable {
        let source: String
    }

    private enum Constants {
        static let gitHubHost = "raw.githubusercontent.com"
        static let getMethod = "GET"
        static let masterPrefix = "https://raw.githubusercontent.com/novasamatech/nova-utils/master/"
        static let refsMasterPrefix = "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/"
        static let callerTimeout: TimeInterval = 4
    }

    private let config = ApplicationConfig.shared
    private let mirrorBody = Data(#"{"source":"mirror"}"#.utf8)
    private let gitHubBody = Data(#"{"source":"github"}"#.utf8)
    private let factory = BaseFetchOperationFactory()

    override func setUpWithError() throws {
        try super.setUpWithError()

        let mirrorHost = try XCTUnwrap(config.configMirrorBaseURL.host)

        ConfigMirrorStubURLProtocol.reset(hosts: [Constants.gitHubHost, mirrorHost])

        XCTAssertTrue(URLProtocol.registerClass(ConfigMirrorStubURLProtocol.self))
    }

    override func tearDown() {
        URLProtocol.unregisterClass(ConfigMirrorStubURLProtocol.self)
        ConfigMirrorStubURLProtocol.reset()

        super.tearDown()
    }

    func testDecodesMirrorBodyAndSkipsGitHub() throws {
        // given
        let gitHubUrl = config.globalConfigURL
        let mirrorUrl = try mirrorUrl(for: gitHubUrl, prefix: Constants.masterPrefix)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let payload = try fetch(factory.createFetchOperation(from: gitHubUrl))

        // then
        XCTAssertEqual(payload, Payload(source: "mirror"))
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
    }

    func testFallsBackToGitHubKeepingRequestSettings() throws {
        // given
        let gitHubUrl = try XCTUnwrap(URL(string: config.legalDocumentsPath)).appendingPathComponent("documents.json")
        let mirrorUrl = try mirrorUrl(for: gitHubUrl, prefix: Constants.refsMasterPrefix)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 503, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let payload = try fetch(
            factory.createFetchOperation(
                from: gitHubUrl,
                shouldUseCache: false,
                timeout: Constants.callerTimeout
            )
        )

        // then
        XCTAssertEqual(payload, Payload(source: "github"))
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
        )

        let requests = ConfigMirrorStubURLProtocol.requests

        XCTAssertEqual(requests.map(\.timeoutInterval), [Constants.callerTimeout, Constants.callerTimeout])
        XCTAssertEqual(
            requests.map(\.cachePolicy),
            [.reloadIgnoringLocalAndRemoteCacheData, .reloadIgnoringLocalAndRemoteCacheData]
        )
        XCTAssertEqual(requests.map(\.httpMethod), [Constants.getMethod, Constants.getMethod])
        XCTAssertEqual(
            requests.last?.value(forHTTPHeaderField: HttpHeaderKey.contentType.rawValue),
            HttpContentType.json.rawValue
        )
    }

    func testBoundsMirrorAttemptAndKeepsDefaultsForGitHub() throws {
        // given
        let gitHubUrl = config.preferredValidatorsURL
        let mirrorUrl = try mirrorUrl(for: gitHubUrl, prefix: Constants.masterPrefix)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .failure(.timedOut))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let payload = try fetch(factory.createFetchOperation(from: gitHubUrl))

        // then
        XCTAssertEqual(payload, Payload(source: "github"))

        let requests = ConfigMirrorStubURLProtocol.requests
        let plainRequest = URLRequest(url: gitHubUrl)

        XCTAssertEqual(
            requests.map(\.timeoutInterval),
            [ConfigMirrorFetchOperationFactory.Constants.mirrorTimeout, plainRequest.timeoutInterval]
        )
        XCTAssertEqual(requests.map(\.cachePolicy), [plainRequest.cachePolicy, plainRequest.cachePolicy])
    }

    func testFallsBackToGitHubWhenMirrorBodyCanNotBeDecoded() throws {
        // given
        let gitHubUrl = config.bittensorConfigURL
        let mirrorUrl = try mirrorUrl(for: gitHubUrl, prefix: Constants.masterPrefix)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: Data("<html>".utf8)))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let payload = try fetch(factory.createFetchOperation(from: gitHubUrl))

        // then
        XCTAssertEqual(payload, Payload(source: "github"))
    }

    func testReportsGitHubFailureWhenBothFail() throws {
        // given
        let gitHubUrl = config.globalConfigURL
        let mirrorUrl = try mirrorUrl(for: gitHubUrl, prefix: Constants.masterPrefix)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 500, body: Data()))

        // when
        XCTAssertThrowsError(try fetch(factory.createFetchOperation(from: gitHubUrl))) { error in
            // then
            XCTAssertEqual(error as? NetworkResponseError, .internalServerError)
        }
    }

    func testFetchesDelegateRegistryDirectly() throws {
        // given
        let gitHubUrl = GovernanceDelegateMetadataFactory.baseUrl.appendingPathComponent("polkadot.json")

        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let operation: BaseOperation<Payload> = factory.createFetchOperation(from: gitHubUrl)
        let payload = try fetch(operation)

        // then
        XCTAssertTrue(operation is NetworkOperation<Payload>)
        XCTAssertEqual(payload, Payload(source: "github"))
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [gitHubUrl.absoluteString])
    }
}

private extension BaseFetchOperationFactoryTests {
    func mirrorUrl(for gitHubUrl: URL, prefix: String) throws -> URL {
        let original = gitHubUrl.absoluteString

        XCTAssertTrue(original.hasPrefix(prefix))

        let filePath = String(original.dropFirst(prefix.count))

        return try XCTUnwrap(URL(string: config.configMirrorBaseURL.absoluteString + filePath))
    }

    func fetch(_ operation: BaseOperation<Payload>) throws -> Payload {
        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }
}
