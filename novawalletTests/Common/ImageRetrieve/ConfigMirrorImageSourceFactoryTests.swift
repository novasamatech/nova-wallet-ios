import XCTest
import UIKit
import Kingfisher
@testable import novawallet

final class ConfigMirrorImageSourceFactoryTests: XCTestCase {
    private enum Constants {
        static let mirrorHost = "mirror.novatest"
        static let gitHubHost = "github.novatest"
        static let otherHost = "other.novatest"
        static let expectationTimeout: TimeInterval = 10
    }

    private let gitHubUrl = URL(string: "https://github.novatest/novasamatech/nova-utils/master/icons/chains/Polkadot.png")!
    private let mirrorUrl = URL(string: "https://mirror.novatest/v1/config/icons/chains/Polkadot.png")!
    private let otherUrl = URL(string: "https://other.novatest/dapps/icon.png")!

    private var factory: ConfigMirrorImageSourceFactory!
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

        let resolver = ConfigMirrorURLResolver(
            mirrorBaseURL: URL(string: "https://\(Constants.mirrorHost)/v1/config/")!,
            sources: ["\(Constants.gitHubHost)/novasamatech/nova-utils/master/"]
        )

        factory = ConfigMirrorImageSourceFactory(urlResolver: resolver)

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
