import XCTest
@testable import novawallet

final class ConfigMirrorURLResolverTests: XCTestCase {
    private let gitHub = "https://raw.githubusercontent.com/novasamatech"
    private let mirror = "https://mirror.novatest/v1/config"

    private let resolver = ConfigMirrorURLResolver(
        mirrorBaseURL: URL(string: "https://mirror.novatest/v1/config/")!,
        sources: [
            "raw.githubusercontent.com/novasamatech/nova-utils/master/",
            "raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/"
        ]
    )

    func testMapsBothMasterFormsKeepingPathAsIs() throws {
        // the last url is how the banners module builds its urls: NSString helpers collapse "https://"
        let collapsedUrl = ("\(gitHub)/nova-utils/refs/heads/master/banners/v2/" as NSString)
            .appendingPathComponent("assets/banners.json")

        XCTAssertTrue(collapsedUrl.hasPrefix("https:/raw.githubusercontent.com"))

        let mapping = [
            "\(gitHub)/nova-utils/master/chains/v23/chains.json": "\(mirror)/chains/v23/chains.json",
            "\(gitHub)/nova-utils/refs/heads/master/legal/v1/documents.json": "\(mirror)/legal/v1/documents.json",
            "\(gitHub)/nova-utils/master/chains/v23/preConfigured/details/0xabc.json":
                "\(mirror)/chains/v23/preConfigured/details/0xabc.json",
            "\(gitHub)/nova-utils/master/icons/My%20Token%2B1%25.svg": "\(mirror)/icons/My%20Token%2B1%25.svg",
            collapsedUrl: "\(mirror)/banners/v2/assets/banners.json"
        ]

        for (original, expected) in mapping {
            let url = try XCTUnwrap(URL(string: original))

            XCTAssertEqual(resolver.mirrorURL(for: url)?.absoluteString, expected)
        }
    }

    func testLeavesEverythingElseWhereItIs() throws {
        let notMirrored = [
            "\(gitHub)/nova-wallet-ios-releases/master/updates/v1/entrypoint_dev.json",
            "\(gitHub)/nova-utils-fork/master/chains/v23/chains.json",
            "https://raw.githubusercontent.com/other/nova-utils/master/chains/v23/chains.json",
            "\(gitHub)/nova-utils/develop/chains/v23/chains.json",
            "\(gitHub)/nova-utils/refs/heads/develop/chains/v23/chains.json",
            "\(gitHub)/nova-utils/master-next/chains/v23/chains.json",
            "\(gitHub)/nova-utils/master/",
            "https://evil.example/raw.githubusercontent.com/novasamatech/nova-utils/master/chains.json",
            "https://raw.githubusercontent.com.evil.example/novasamatech/nova-utils/master/chains.json",
            "http://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v23/chains.json",
            "\(mirror)/chains/v23/chains.json"
        ]

        for original in notMirrored {
            let url = try XCTUnwrap(URL(string: original))

            XCTAssertNil(resolver.mirrorURL(for: url), original)
        }
    }

    func testAppConfigMapsEveryNovaUtilsUrlToMirror() throws {
        let config = ApplicationConfig.shared
        let appResolver = ConfigMirrorURLResolver(applicationConfig: config)
        let mirrorBase = config.configMirrorBaseURL.absoluteString

        XCTAssertTrue(mirrorBase.hasSuffix("/v1/config/"))

        var urls = [
            config.chainListURL,
            config.defaultAssetsURL,
            config.preConfiguredLightChainListURL,
            config.preConfiguredChainDirectoryURL.appendingPathComponent("0xabc.json"),
            config.evmAssetsURL,
            config.xcmTransfersURL,
            config.xcmDynamicTransfersURL,
            config.globalConfigURL,
            config.dAppsListURL,
            config.preferredValidatorsURL,
            config.bittensorConfigURL,
            config.governanceDAppsListURL,
            config.commonTypesURL,
            config.slip44URL
        ]

        let pathPrefixes = [
            config.whiteAppearanceIconsPath,
            config.coloredAppearanceIconsPath,
            config.bannersContentPath,
            config.assetHubMigrationConfigsPath,
            config.legalDocumentsPath,
            config.announcementsPath
        ]

        for prefix in pathPrefixes {
            try urls.append(XCTUnwrap(URL(string: prefix + "file.json")))
            try urls.append(XCTUnwrap(URL(string: (prefix as NSString).appendingPathComponent("file.json"))))
        }

        for url in urls {
            let mirrorUrl = appResolver.mirrorURL(for: url)?.absoluteString ?? ""

            XCTAssertTrue(mirrorUrl.hasPrefix(mirrorBase), url.absoluteString)
            XCTAssertTrue(mirrorUrl.hasSuffix("/" + url.lastPathComponent), url.absoluteString)
        }

        XCTAssertEqual(
            appResolver.mirrorURL(for: config.commonTypesURL)?.absoluteString,
            mirrorBase + "chains/types/default.json"
        )

        XCTAssertNil(appResolver.mirrorURL(for: config.inAppUpdatesEntrypointURL))
        XCTAssertNil(appResolver.mirrorURL(for: config.logoURL))
        XCTAssertNil(appResolver.mirrorURL(for: GovernanceDelegateMetadataFactory.baseUrl.appendingPathComponent("a.json")))
    }
}
