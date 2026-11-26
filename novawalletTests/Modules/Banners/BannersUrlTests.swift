import XCTest
import Kingfisher
import Operation_iOS
@testable import novawallet

private final class BannersFetchFactorySpy: BaseFetchOperationFactory {
    private(set) var urls: [URL] = []

    override func createRequestFactory(
        from url: URL,
        shouldUseCache: Bool,
        timeout: TimeInterval?
    ) -> BlockNetworkRequestFactory {
        urls.append(url)

        return super.createRequestFactory(from: url, shouldUseCache: shouldUseCache, timeout: timeout)
    }
}

/// The banner files are requested by urls the config mirror recognizes: with a host and nothing collapsed
final class BannersUrlTests: XCTestCase {
    private let contentPath = "https://raw.novatest/novasamatech/nova-utils/master/banners/v2/content/"
    private let operationManager = OperationManager(operationQueue: OperationQueue())

    func testBannersListUrlKeepsContentPathAndAddsDomainDirectory() throws {
        let url = try bannersListUrl(for: .assets, contentPath: contentPath)

        XCTAssertEqual(url.host, "raw.novatest")
        XCTAssertEqual(url.deletingLastPathComponent().absoluteString, contentPath + "assets/")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("banners"))
        XCTAssertEqual(url.pathExtension, "json")
    }

    func testLocalizationUrlKeepsContentPathAndAddsDomainAndLanguage() throws {
        let url = try localizationUrl(for: .dApps, contentPath: contentPath)

        XCTAssertEqual(url.host, "raw.novatest")
        XCTAssertTrue(url.absoluteString.hasPrefix(contentPath + "dapps/localized"))
        XCTAssertEqual(url.pathComponents.count, try XCTUnwrap(URL(string: contentPath)).pathComponents.count + 3)
        XCTAssertEqual(url.lastPathComponent, "en.json")
    }

    func testAppBannerUrlsAreReadFromConfigMirror() throws {
        let config = ApplicationConfig.shared
        let resolver = ConfigMirrorURLResolver(applicationConfig: config)
        let mirrorDirectory = config.configMirrorBaseURL.absoluteString + "banners/v2/content/"

        let urls = try [
            bannersListUrl(for: .assets, contentPath: config.bannersContentPath),
            bannersListUrl(for: .dApps, contentPath: config.bannersContentPath),
            localizationUrl(for: .assets, contentPath: config.bannersContentPath),
            localizationUrl(for: .ahmPolkadot, contentPath: config.bannersContentPath)
        ]

        for url in urls {
            let mirrorUrl = try XCTUnwrap(resolver.mirrorURL(for: url), url.absoluteString)

            XCTAssertTrue(mirrorUrl.absoluteString.hasPrefix(mirrorDirectory), url.absoluteString)
            XCTAssertEqual(mirrorUrl.lastPathComponent, url.lastPathComponent)
        }
    }
}

private extension BannersUrlTests {
    func bannersListUrl(for domain: Banners.Domain, contentPath: String) throws -> URL {
        let fetchFactory = BannersFetchFactorySpy()
        let imageManager = KingfisherManager.shared

        let factory = BannersFetchOperationFactory(
            domain: domain,
            bannersContentPath: contentPath,
            fetchOperationFactory: fetchFactory,
            imageRetrieveOperationFactory: ImageRetrieveOperationFactory(
                imageManager: imageManager,
                remoteProvider: CommonRemoteImageProvider(imageManager: imageManager)
            ),
            operationManager: operationManager
        )

        // the operations are only created: nothing is requested
        let imageInfo = CommonImageInfo(size: .zero, scale: 1)
        _ = factory.createWrapper(backgroundImageInfo: imageInfo, contentImageInfo: imageInfo)

        XCTAssertEqual(fetchFactory.urls.count, 1)

        return try XCTUnwrap(fetchFactory.urls.first)
    }

    func localizationUrl(for domain: Banners.Domain, contentPath: String) throws -> URL {
        let fetchFactory = BannersFetchFactorySpy()

        let factory = BannersLocalizationFactory(
            domain: domain,
            bannersContentPath: contentPath,
            fetchOperationFactory: fetchFactory,
            textHeightOperationFactory: TextHeightOperationFactory(),
            operationManager: operationManager
        )

        _ = factory.createWrapper(for: Locale(identifier: "en"), availableWidth: 320)

        XCTAssertEqual(fetchFactory.urls.count, 1)

        return try XCTUnwrap(fetchFactory.urls.first)
    }
}
