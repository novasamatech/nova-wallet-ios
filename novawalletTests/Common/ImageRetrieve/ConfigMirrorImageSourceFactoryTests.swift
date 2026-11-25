import XCTest
import UIKit
import Kingfisher
@testable import novawallet

final class ConfigMirrorImageSourceFactoryTests: XCTestCase {
    private enum Constants {
        static let mirrorHost = "mirror.novatest"
        static let gitHubHost = "github.novatest"
        static let otherHost = "other.novatest"
        static let mirrorTimeout: TimeInterval = 4
        static let cooldown: TimeInterval = 60
        static let expectationTimeout: TimeInterval = 10
    }

    private let gitHubUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/icons/chains/Polkadot.png")!
    private let mirrorUrl = URL(string: "https://mirror.novatest/v1/config/icons/chains/Polkadot.png")!
    private let otherUrl = URL(string: "https://other.novatest/dapps/icon.png")!

    private let gitHubLogoUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/icons/chains/Kusama.png")!
    private let mirrorLogoUrl = URL(string: "https://mirror.novatest/v1/config/icons/chains/Kusama.png")!

    private var factory: ConfigMirrorImageSourceFactory!
    private var clock: ConfigMirrorTestClock!
    private var availability: ConfigMirrorAvailability!
    private var logger: ConfigMirrorLoggerSpy!
    private var downloader: ImageDownloader!
    private var cache: ImageCache!
    private var cacheDirectory: URL!
    private var manager: KingfisherManager!
    private var imageData: Data!

    override func setUpWithError() throws {
        try super.setUpWithError()

        ConfigMirrorStubURLProtocol.reset(
            hosts: [Constants.mirrorHost, Constants.gitHubHost, Constants.otherHost]
        )

        let clock = ConfigMirrorTestClock()

        self.clock = clock
        availability = ConfigMirrorAvailability(cooldown: Constants.cooldown) { clock.uptime }
        logger = ConfigMirrorLoggerSpy()
        factory = makeFactory(mirrorTimeout: Constants.mirrorTimeout)

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [ConfigMirrorStubURLProtocol.self]

        let name = "config-mirror-tests-\(UUID().uuidString)"

        downloader = ImageDownloader(name: name)
        downloader.sessionConfiguration = sessionConfiguration

        cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        cache = try ImageCache(name: name, cacheDirectoryURL: cacheDirectory)

        manager = KingfisherManager(downloader: downloader, cache: cache)

        let size = CGSize(width: 2, height: 2)

        imageData = UIGraphicsImageRenderer(size: size).pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    override func tearDownWithError() throws {
        ConfigMirrorStubURLProtocol.reset()

        try? FileManager.default.removeItem(at: cacheDirectory)

        try super.tearDownWithError()
    }

    func testMirroredSourceLoadsMirrorFirstAndKeepsOriginalCacheKey() throws {
        // when
        let imageSource = factory.createSource(for: gitHubUrl)

        // then
        XCTAssertEqual(imageSource.source.url, mirrorUrl)
        XCTAssertEqual(imageSource.source.cacheKey, gitHubUrl.absoluteString)

        let alternatives = try XCTUnwrap(KingfisherParsedOptionsInfo(imageSource.options).alternativeSources)

        XCTAssertEqual(alternatives.map(\.url), [gitHubUrl])
        XCTAssertEqual(alternatives.map(\.cacheKey), [gitHubUrl.absoluteString])
    }

    func testMirroredSourceShortensOnlyMirrorRequest() throws {
        // given
        let modifier = try XCTUnwrap(
            KingfisherParsedOptionsInfo(factory.createSource(for: gitHubUrl).options).requestModifier
        )

        let downloadTimeout: TimeInterval = 15
        let requestPolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        var modifiedRequests: [URLRequest?] = []

        // when
        for url in [mirrorUrl, gitHubUrl, mirrorLogoUrl] {
            let request = URLRequest(url: url, cachePolicy: requestPolicy, timeoutInterval: downloadTimeout)
            modifier.modified(for: request) { modifiedRequests.append($0) }
        }

        // then
        XCTAssertEqual(modifiedRequests.compactMap { $0?.url }, [mirrorUrl, gitHubUrl, mirrorLogoUrl])
        XCTAssertEqual(
            modifiedRequests.compactMap { $0?.timeoutInterval },
            [Constants.mirrorTimeout, downloadTimeout, downloadTimeout]
        )
        XCTAssertEqual(modifiedRequests.compactMap { $0?.cachePolicy }, [requestPolicy, requestPolicy, requestPolicy])
    }

    func testDefaultMirrorTimeoutIsTheSharedConstant() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: imageData))

        factory = ConfigMirrorImageSourceFactory(urlResolver: resolver, availability: availability, logger: logger)

        // when
        XCTAssertNoThrow(try retrieveImage(for: gitHubUrl).get())

        // then
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requests.map(\.timeoutInterval),
            [ConfigMirrorConstants.attemptTimeout]
        )
    }

    func testNotMirroredSourceIsThePlainUrl() {
        // when
        let imageSource = factory.createSource(for: otherUrl)

        // then
        XCTAssertEqual(imageSource.source.url, otherUrl)
        XCTAssertEqual(imageSource.source.cacheKey, otherUrl.absoluteString)
        XCTAssertTrue(imageSource.options.isEmpty)
    }

    func testRetrievesFromMirrorAndCachesUnderOriginalUrl() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: imageData))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: imageData))

        // when
        let result = retrieveImage(for: gitHubUrl)

        // then
        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
        XCTAssertTrue(cache.isCached(forKey: gitHubUrl.absoluteString))
        XCTAssertFalse(cache.isCached(forKey: mirrorUrl.absoluteString))
    }

    func testRetrievesFromGitHubWhenMirrorFailsAndCachesUnderOriginalUrl() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 404, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: imageData))

        // when
        let result = retrieveImage(for: gitHubUrl)

        // then
        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
        )
        XCTAssertTrue(cache.isCached(forKey: gitHubUrl.absoluteString))
        XCTAssertFalse(cache.isCached(forKey: mirrorUrl.absoluteString))

        // the mirror attempt is the short one, the original url keeps the downloader's timeout
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requests.map(\.timeoutInterval),
            [Constants.mirrorTimeout, downloader.downloadTimeout]
        )

        // a missing file is not a reason to give up on the mirror
        XCTAssertTrue(availability.isAvailable)
        XCTAssertEqual(logger.warnings.count, 1)
        XCTAssertTrue(logger.warning(at: 0).contains("/v1/config/icons/chains/Polkadot.png"))
    }

    func testRetrievesFromGitHubWhenMirrorHangsAndThenSkipsMirror() throws {
        // given
        factory = makeFactory(mirrorTimeout: 0.5)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .hanging)
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: imageData))
        ConfigMirrorStubURLProtocol.stub(mirrorLogoUrl, with: .hanging)
        ConfigMirrorStubURLProtocol.stub(gitHubLogoUrl, with: .response(statusCode: 200, body: imageData))

        // when
        XCTAssertNoThrow(try retrieveImage(for: gitHubUrl).get())

        // then
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
        )
        XCTAssertFalse(availability.isAvailable)
        XCTAssertEqual(logger.warnings.count, 2)
        XCTAssertTrue(logger.warning(at: 1).contains("cool-down"))

        // when
        let imageSource = factory.createSource(for: gitHubLogoUrl)

        XCTAssertEqual(imageSource.source.url, gitHubLogoUrl)
        XCTAssertTrue(imageSource.options.isEmpty)
        XCTAssertNoThrow(try retrieveImage(for: gitHubLogoUrl).get())
        XCTAssertNoThrow(try downloadImage(for: gitHubLogoUrl).get())

        // then
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [
                mirrorUrl.absoluteString,
                gitHubUrl.absoluteString,
                gitHubLogoUrl.absoluteString,
                gitHubLogoUrl.absoluteString
            ]
        )
    }

    func testTriesMirrorAgainWhenCooldownEnds() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .failure(.timedOut))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: imageData))

        XCTAssertNoThrow(try downloadImage(for: gitHubUrl).get())
        XCTAssertFalse(availability.isAvailable)

        // when
        clock.advance(by: Constants.cooldown)

        // then
        XCTAssertEqual(factory.createSource(for: gitHubLogoUrl).source.url, mirrorLogoUrl)
    }

    func testCancelledMirrorLoadSaysNothingAboutMirror() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .hanging)
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: imageData))

        let mirrorUrl = mirrorUrl

        let mirrorRequested = expectation(description: "mirror requested")
        mirrorRequested.assertForOverFulfill = false

        ConfigMirrorStubURLProtocol.observeRequests { request in
            if request.url == mirrorUrl {
                mirrorRequested.fulfill()
            }
        }

        let imageSource = factory.createSource(for: gitHubUrl)
        let completed = expectation(description: "load completed")

        var loadResult: Result<RetrieveImageResult, KingfisherError>?

        // when
        let task = manager.retrieveImage(with: imageSource.source, options: imageSource.options) { result in
            loadResult = result
            completed.fulfill()
        }

        wait(for: [mirrorRequested], timeout: Constants.expectationTimeout)

        task?.cancel()

        wait(for: [completed], timeout: Constants.expectationTimeout)

        // then
        XCTAssertThrowsError(try XCTUnwrap(loadResult).get()) { error in
            XCTAssertEqual((error as? KingfisherError)?.isTaskCancelled, true)
        }

        XCTAssertTrue(availability.isAvailable)
        XCTAssertTrue(logger.warnings.isEmpty)
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
    }

    func testRetrievesFromGitHubOnMirrorNetworkError() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .failure(.cannotConnectToHost))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: imageData))

        // when
        let result = retrieveImage(for: gitHubUrl)

        // then
        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
        )
    }

    func testImageCachedBeforeMirrorIsReusedWithoutRequests() throws {
        // given
        let image = try XCTUnwrap(UIImage(data: imageData))
        let stored = expectation(description: "image stored")

        cache.store(image, forKey: gitHubUrl.absoluteString) { _ in
            stored.fulfill()
        }

        wait(for: [stored], timeout: Constants.expectationTimeout)

        // when
        let result = retrieveImage(for: gitHubUrl)

        // then
        XCTAssertNotEqual(try result.get().cacheType, CacheType.none)
        XCTAssertTrue(ConfigMirrorStubURLProtocol.requestedUrls.isEmpty)
    }

    func testFailsWhenMirrorAndGitHubFail() {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 503, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 404, body: Data()))

        // when
        let result = retrieveImage(for: gitHubUrl)

        // then
        XCTAssertThrowsError(try result.get()) { error in
            let kingfisherError = error as? KingfisherError

            XCTAssertEqual(kingfisherError?.isTaskCancelled, false)
            XCTAssertEqual(kingfisherError?.isNotCurrentTask, false)
        }

        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
        )
    }

    func testDownloadsFromMirrorOnly() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 200, body: imageData))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: imageData))

        // when
        let result = downloadImage(for: gitHubUrl)

        // then
        XCTAssertNoThrow(try result.get())
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [mirrorUrl.absoluteString])
    }

    func testDownloadsFromGitHubWhenMirrorFails() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .response(statusCode: 503, body: Data()))
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: imageData))

        // when
        let result = downloadImage(for: gitHubUrl)

        // then
        XCTAssertEqual(try result.get().url, gitHubUrl)
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString]
        )
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requests.map(\.timeoutInterval),
            [Constants.mirrorTimeout, downloader.downloadTimeout]
        )
        XCTAssertTrue(availability.isAvailable)
        XCTAssertEqual(logger.warnings.count, 1)
        XCTAssertTrue(logger.warning(at: 0).contains("/v1/config/icons/chains/Polkadot.png"))
    }

    func testDownloadsFromGitHubWhenMirrorHangsAndThenSkipsMirror() throws {
        // given
        factory = makeFactory(mirrorTimeout: 0.5)

        ConfigMirrorStubURLProtocol.stub(mirrorUrl, with: .hanging)
        ConfigMirrorStubURLProtocol.stub(gitHubUrl, with: .response(statusCode: 200, body: imageData))

        // when
        XCTAssertNoThrow(try downloadImage(for: gitHubUrl).get())
        XCTAssertNoThrow(try downloadImage(for: gitHubUrl).get())

        // then
        XCTAssertEqual(
            ConfigMirrorStubURLProtocol.requestedUrls,
            [mirrorUrl.absoluteString, gitHubUrl.absoluteString, gitHubUrl.absoluteString]
        )
        XCTAssertFalse(availability.isAvailable)
        XCTAssertEqual(logger.warnings.count, 2)
    }

    func testDownloadsNotMirroredUrlOnce() throws {
        // given
        ConfigMirrorStubURLProtocol.stub(otherUrl, with: .response(statusCode: 404, body: Data()))

        // when
        let result = downloadImage(for: otherUrl)

        // then
        XCTAssertThrowsError(try result.get())
        XCTAssertEqual(ConfigMirrorStubURLProtocol.requestedUrls, [otherUrl.absoluteString])
    }
}

private extension ConfigMirrorImageSourceFactoryTests {
    var resolver: ConfigMirrorURLResolver {
        ConfigMirrorURLResolver(
            mirrorBaseURL: URL(string: "https://\(Constants.mirrorHost)/v1/config/")!,
            sources: ["\(Constants.gitHubHost)/novasamatech/nova-utils/master/"]
        )
    }

    func makeFactory(mirrorTimeout: TimeInterval) -> ConfigMirrorImageSourceFactory {
        ConfigMirrorImageSourceFactory(
            urlResolver: resolver,
            availability: availability,
            mirrorTimeout: mirrorTimeout,
            logger: logger
        )
    }

    func retrieveImage(for url: URL) -> Result<RetrieveImageResult, KingfisherError> {
        let imageSource = factory.createSource(for: url)
        let completed = expectation(description: "image retrieved")

        var retrieveResult: Result<RetrieveImageResult, KingfisherError>?

        manager.retrieveImage(with: imageSource.source, options: imageSource.options) { result in
            retrieveResult = result
            completed.fulfill()
        }

        wait(for: [completed], timeout: Constants.expectationTimeout)

        return retrieveResult ?? .failure(.requestError(reason: .emptyRequest))
    }

    func downloadImage(for url: URL) -> Result<ImageLoadingResult, KingfisherError> {
        let completed = expectation(description: "image downloaded")

        var downloadResult: Result<ImageLoadingResult, KingfisherError>?

        factory.downloadImage(with: url, using: downloader, options: []) { result in
            downloadResult = result
            completed.fulfill()
        }

        wait(for: [completed], timeout: Constants.expectationTimeout)

        return downloadResult ?? .failure(.requestError(reason: .emptyRequest))
    }
}
