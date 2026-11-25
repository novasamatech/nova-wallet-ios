import XCTest
import Operation_iOS
@testable import novawallet

final class DataOperationFactoryTests: XCTestCase {
    private enum Constants {
        static let gitHubHost = "raw.githubusercontent.com"
        static let getMethod = "GET"
        static let masterPrefix = "https://raw.githubusercontent.com/novasamatech/nova-utils/master/"
        static let refsMasterPrefix = "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/"
        static let callerTimeout: TimeInterval = 5
    }

    private let config = ApplicationConfig.shared
    private let mirrorBody = Data("mirror".utf8)
    private let gitHubBody = Data("github".utf8)

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

    func testReadsChainListFromMirrorWithPlainGet() throws {
        // given
        let gitHubUrl = config.chainListURL
        let mirrorUrl = try mirrorUrl(for: gitHubUrl, prefix: Constants.masterPrefix)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let data = try fetch(gitHubUrl, using: DataOperationFactory())

        // then
        XCTAssertEqual(data, mirrorBody)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])

        let request = try XCTUnwrap(ConfigMirrorStubURLProtocol.requests.first)

        XCTAssertEqual(request.httpMethod, Constants.getMethod)
        XCTAssertTrue(request.allHTTPHeaderFields?.isEmpty ?? true)
        XCTAssertEqual(request.cachePolicy, .useProtocolCachePolicy)
        XCTAssertEqual(request.timeoutInterval, ConfigMirrorFetchOperationFactory.Constants.mirrorTimeout)
    }

    func testReadsRefsHeadsMasterFileFromMirror() throws {
        // given
        let gitHubUrl = try XCTUnwrap(URL(string: config.coloredAppearanceIconsPath + "DOT.svg"))
        let mirrorUrl = try mirrorUrl(for: gitHubUrl, prefix: Constants.refsMasterPrefix)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: mirrorBody))

        // when
        let data = try fetch(gitHubUrl, using: DataOperationFactory())

        // then
        XCTAssertEqual(data, mirrorBody)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
    }

    func testFallsBackToGitHubKeepingCachePolicyAndTimeout() throws {
        // given
        let gitHubUrl = config.defaultAssetsURL
        let mirrorUrl = try mirrorUrl(for: gitHubUrl, prefix: Constants.masterPrefix)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        let factory = DataOperationFactory(timeout: Constants.callerTimeout, ignoresCache: true)

        // when
        let data = try fetch(gitHubUrl, using: factory)

        // then
        XCTAssertEqual(data, gitHubBody)
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
    }

    func testFallsBackToGitHubWithDefaultRequestWhenFactoryHasNoSettings() throws {
        // given
        let gitHubUrl = config.commonTypesURL
        let mirrorUrl = try mirrorUrl(for: gitHubUrl, prefix: Constants.masterPrefix)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .failure(.cannotFindHost))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let data = try fetch(gitHubUrl, using: DataOperationFactory())

        // then
        XCTAssertEqual(data, gitHubBody)

        let gitHubRequest = try XCTUnwrap(ConfigMirrorStubURLProtocol.requests.last)
        let plainRequest = URLRequest(url: gitHubUrl)

        XCTAssertEqual(gitHubRequest.url, gitHubUrl)
        XCTAssertEqual(gitHubRequest.timeoutInterval, plainRequest.timeoutInterval)
        XCTAssertEqual(gitHubRequest.cachePolicy, plainRequest.cachePolicy)
        XCTAssertTrue(gitHubRequest.allHTTPHeaderFields?.isEmpty ?? true)
    }

    func testFetchesOtherGitHubRepositoryDirectly() throws {
        // given
        let gitHubUrl = config.inAppUpdatesEntrypointURL

        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: gitHubBody))

        // when
        let data = try fetch(gitHubUrl, using: DataOperationFactory())

        // then
        XCTAssertEqual(data, gitHubBody)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [gitHubUrl.absoluteString])
    }
}

private extension DataOperationFactoryTests {
    func mirrorUrl(for gitHubUrl: URL, prefix: String) throws -> URL {
        let original = gitHubUrl.absoluteString

        XCTAssertTrue(original.hasPrefix(prefix))

        let filePath = String(original.dropFirst(prefix.count))

        return try XCTUnwrap(URL(string: config.configMirrorBaseURL.absoluteString + filePath))
    }

    func fetch(_ url: URL, using factory: DataOperationFactoryProtocol) throws -> Data {
        let operation = factory.fetchData(from: url)

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        return try operation.extractNoCancellableResultData()
    }
}
