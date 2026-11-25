import XCTest
import Kingfisher
import Operation_iOS
@testable import novawallet

/// The real fetch paths against the registered protocol: only the transport under it is replaced
final class ConfigMirrorRegisteredProtocolTests: XCTestCase {
    private let gitHubPrefix = "https://github.novatest/novasamatech/nova-utils/master/"
    private let mirrorPrefix = "https://mirror.novatest/v1/config/"
    private let redPixelPng = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
    private let expectationTimeout: TimeInterval = 10

    private var savedDependencies: ConfigMirrorURLProtocol.Dependencies!
    private var loader: ConfigMirrorFakeLoader!
    private var imageManager: KingfisherManager!

    override func setUp() {
        super.setUp()

        savedDependencies = ConfigMirrorURLProtocol.dependencies
        loader = ConfigMirrorFakeLoader()

        ConfigMirrorURLProtocol.dependencies = ConfigMirrorURLProtocol.Dependencies(
            urlResolver: ConfigMirrorURLResolver(
                mirrorBaseURL: URL(string: mirrorPrefix)!,
                sources: ["github.novatest/novasamatech/nova-utils/master/"]
            ),
            availability: ConfigMirrorAvailability(),
            loader: loader,
            logger: ConfigMirrorLoggerSpy()
        )

        let name = "config-mirror-tests-\(UUID().uuidString)"
        let downloader = ImageDownloader(name: name)

        imageManager = KingfisherManager(downloader: downloader, cache: ImageCache(name: name))

        ConfigMirrorURLProtocol.register(for: downloader)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(ConfigMirrorURLProtocol.self)
        ConfigMirrorURLProtocol.dependencies = savedDependencies
        imageManager.cache.clearCache()

        super.tearDown()
    }

    func testDataFetchIsAnsweredByMirrorAndFallsBackToOriginalUrl() throws {
        // given
        let mirrorBodies = [
            mirrorPrefix + "chains/v23/chains.json": #"{"source":"mirror"}"#,
            mirrorPrefix + "chains/v23/broken.json": "<html>",
            mirrorPrefix + "banners/v2/banners.json": "[]"
        ]

        loader.answerClosure = { url in Data((mirrorBodies[url] ?? #"{"source":"github"}"#).utf8) }

        // the banners module builds such urls: they have no host for the system but are loaded all the same
        let collapsedUrl = (gitHubPrefix as NSString).appendingPathComponent("banners/v2/banners.json")

        XCTAssertNil(URL(string: collapsedUrl)?.host)

        // when
        let bodies = try [gitHubPrefix + "chains/v23/chains.json", gitHubPrefix + "chains/v23/broken.json", collapsedUrl]
            .map { try XCTUnwrap(URL(string: $0)) }
            .map { url -> String? in
                let operation = DataOperationFactory().fetchData(from: url)

                OperationQueue().addOperations([operation], waitUntilFinished: true)

                return try String(data: operation.extractNoCancellableResultData(), encoding: .utf8)
            }

        // then
        XCTAssertEqual(bodies, [#"{"source":"mirror"}"#, #"{"source":"github"}"#, "[]"])
        XCTAssertEqual(
            loader.requestedUrls,
            [
                mirrorPrefix + "chains/v23/chains.json",
                mirrorPrefix + "chains/v23/broken.json",
                gitHubPrefix + "chains/v23/broken.json",
                mirrorPrefix + "banners/v2/banners.json"
            ]
        )
    }

    func testImageIsLoadedFromMirrorAndCachedUnderOriginalUrl() throws {
        // given
        let gitHubUrl = try XCTUnwrap(URL(string: gitHubPrefix + "icons/chains/Polkadot.png"))
        let imageData = try XCTUnwrap(Data(base64Encoded: redPixelPng))

        loader.answerClosure = { _ in imageData }

        // when
        let result = loadImage(from: gitHubUrl, cancellingWhen: nil)

        // then
        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(loader.requestedUrls, [mirrorPrefix + "icons/chains/Polkadot.png"])
        XCTAssertTrue(imageManager.cache.isCached(forKey: gitHubUrl.absoluteString))
    }

    func testCancelledImageLoadStopsMirrorAttemptWithoutFallback() throws {
        // given
        let gitHubUrl = try XCTUnwrap(URL(string: gitHubPrefix + "icons/chains/Kusama.png"))

        let requested = expectation(description: "mirror requested")
        let cancelled = expectation(description: "mirror attempt cancelled")

        // the mirror never answers
        loader.loadClosure = { requested.fulfill() }
        loader.cancelClosure = { cancelled.fulfill() }

        // when
        let result = loadImage(from: gitHubUrl, cancellingWhen: requested)

        wait(for: [cancelled], timeout: expectationTimeout)

        // then
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual((error as? KingfisherError)?.isTaskCancelled, true)
        }

        XCTAssertEqual(loader.requestedUrls, [mirrorPrefix + "icons/chains/Kusama.png"])
    }

    // the unit test host skips the launch sequence, so no test meets the mirror unless it registers the protocol
    func testAppDoesNotRegisterProtocolInTestHost() {
        let protocolClasses = KingfisherManager.shared.downloader.sessionConfiguration.protocolClasses ?? []

        XCTAssertFalse(protocolClasses.contains { $0 == ConfigMirrorURLProtocol.self })
    }

    private func loadImage(
        from url: URL,
        cancellingWhen cancelExpectation: XCTestExpectation?
    ) -> Result<RetrieveImageResult, KingfisherError> {
        let completed = expectation(description: "image load completed")
        var loadResult: Result<RetrieveImageResult, KingfisherError> = .failure(.requestError(reason: .emptyRequest))

        let task = imageManager.retrieveImage(with: Source.network(url)) { result in
            loadResult = result
            completed.fulfill()
        }

        if let cancelExpectation {
            wait(for: [cancelExpectation], timeout: expectationTimeout)
            task?.cancel()
        }

        wait(for: [completed], timeout: expectationTimeout)

        return loadResult
    }
}
