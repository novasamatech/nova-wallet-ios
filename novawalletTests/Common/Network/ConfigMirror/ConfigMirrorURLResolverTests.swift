import XCTest
@testable import novawallet

final class ConfigMirrorURLResolverTests: XCTestCase {
    private let resolver = ConfigMirrorURLResolver(
        mirrorBaseURL: URL(string: "https://mirror.novatest/v1/config/")!,
        sources: [
            "raw.githubusercontent.com/novasamatech/nova-utils/master/",
            "raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/"
        ]
    )

    func testMapsMasterForm() {
        assertMirror(
            of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v23/chains.json",
            is: "https://mirror.novatest/v1/config/chains/v23/chains.json"
        )
    }

    func testMapsRefsHeadsMasterForm() {
        assertMirror(
            of: "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/legal/v1/documents.json",
            is: "https://mirror.novatest/v1/config/legal/v1/documents.json"
        )
    }

    func testKeepsNestedPath() {
        assertMirror(
            of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v23/preConfigured/details/0xabc.json",
            is: "https://mirror.novatest/v1/config/chains/v23/preConfigured/details/0xabc.json"
        )
    }

    func testKeepsPercentEncodingOfPath() {
        assertMirror(
            of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/My%20Token%2B1%25.svg",
            is: "https://mirror.novatest/v1/config/icons/My%20Token%2B1%25.svg"
        )
    }

    func testMapsUrlBuiltByAppendingPathComponents() throws {
        let directory = try XCTUnwrap(
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v23/preConfigured/details")
        )

        let url = directory.appendingPathComponent("0xabc").appendingPathExtension("json")

        XCTAssertEqual(
            resolver.mirrorURL(for: url)?.absoluteString,
            "https://mirror.novatest/v1/config/chains/v23/preConfigured/details/0xabc.json"
        )
    }

    // The banners urls are built this way: NSString path helpers collapse the slashes after the scheme
    func testMapsUrlWithCollapsedSchemeSlashes() throws {
        let contentPath = "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/banners/v2/content/"
        let urlString = (contentPath as NSString).appendingPathComponent("assets/banners.json")

        XCTAssertTrue(urlString.hasPrefix("https:/raw.githubusercontent.com"))

        let url = try XCTUnwrap(URL(string: urlString))

        XCTAssertEqual(
            resolver.mirrorURL(for: url)?.absoluteString,
            "https://mirror.novatest/v1/config/banners/v2/content/assets/banners.json"
        )
    }

    func testIgnoresOtherRepository() {
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-wallet-ios-releases/master/updates/v1/entrypoint_dev.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/branding/master/logos/Nova_Wallet_Star_Color.png")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/opengov-delegate-registry/master/registry/polkadot.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils-fork/master/chains/v23/chains.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/other/nova-utils/master/chains/v23/chains.json")
    }

    func testIgnoresOtherBranch() {
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/develop/chains/v23/chains.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/develop/chains/v23/chains.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master-next/chains/v23/chains.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/tags/master/chains/v23/chains.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/feature/master/chains/v23/chains.json")
    }

    func testIgnoresOtherHostAndScheme() {
        assertNoMirror(of: "https://github.com/novasamatech/nova-utils/master/chains/v23/chains.json")
        assertNoMirror(of: "https://evil.example/raw.githubusercontent.com/novasamatech/nova-utils/master/chains.json")
        assertNoMirror(of: "https://raw.githubusercontent.com.evil.example/novasamatech/nova-utils/master/chains.json")
        assertNoMirror(of: "http://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v23/chains.json")
        assertNoMirror(of: "https://mirror.novatest/v1/config/chains/v23/chains.json")
        assertNoMirror(of: "file:///raw.githubusercontent.com/novasamatech/nova-utils/master/chains.json")
    }

    func testIgnoresBranchRootWithoutFilePath() {
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master")
    }

    func testIgnoresPathThatClimbsUp() {
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/../../../v1/other/endpoint?x=1")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/../../secret.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/..")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/..")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/../x.json")
    }

    func testIgnoresPercentEncodedPathThatClimbsUp() {
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/%2e%2e/%2e%2e/v1/other")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/%2E%2E/x.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/%2e%2E/x.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/.%2e/x.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/%2E./x.json")
        assertNoMirror(of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/%2e%2e")
    }

    func testKeepsDotsThatDoNotClimbUp() {
        assertMirror(
            of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/v1.2/a..b/...svg",
            is: "https://mirror.novatest/v1/config/icons/v1.2/a..b/...svg"
        )
        assertMirror(
            of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/./DOT.svg",
            is: "https://mirror.novatest/v1/config/icons/./DOT.svg"
        )
        assertMirror(
            of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/DOT.svg?path=../x#../y",
            is: "https://mirror.novatest/v1/config/icons/DOT.svg?path=../x#../y"
        )
        assertMirror(
            of: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/icons/%252e%252e/DOT.svg",
            is: "https://mirror.novatest/v1/config/icons/%252e%252e/DOT.svg"
        )
    }

    func testAppConfigMapsEveryNovaUtilsUrlToMirror() throws {
        let config = ApplicationConfig.shared
        let appResolver = ConfigMirrorURLResolver(applicationConfig: config)
        let mirrorBase = config.configMirrorBaseURL.absoluteString

        XCTAssertTrue(mirrorBase.hasSuffix("/v1/config/"))

        let fileUrls: [String: URL] = [
            "chainListURL": config.chainListURL,
            "defaultAssetsURL": config.defaultAssetsURL,
            "preConfiguredLightChainListURL": config.preConfiguredLightChainListURL,
            "preConfiguredChainDirectoryURL": config.preConfiguredChainDirectoryURL.appendingPathComponent("0xabc.json"),
            "evmAssetsURL": config.evmAssetsURL,
            "xcmTransfersURL": config.xcmTransfersURL,
            "xcmDynamicTransfersURL": config.xcmDynamicTransfersURL,
            "globalConfigURL": config.globalConfigURL,
            "dAppsListURL": config.dAppsListURL,
            "preferredValidatorsURL": config.preferredValidatorsURL,
            "bittensorConfigURL": config.bittensorConfigURL,
            "governanceDAppsListURL": config.governanceDAppsListURL,
            "commonTypesURL": config.commonTypesURL,
            "slip44URL": config.slip44URL
        ]

        let pathPrefixes: [String: String] = [
            "whiteAppearanceIconsPath": config.whiteAppearanceIconsPath,
            "coloredAppearanceIconsPath": config.coloredAppearanceIconsPath,
            "bannersContentPath": config.bannersContentPath,
            "assetHubMigrationConfigsPath": config.assetHubMigrationConfigsPath,
            "legalDocumentsPath": config.legalDocumentsPath,
            "announcementsPath": config.announcementsPath
        ]

        for (name, url) in fileUrls {
            let mirrorUrl = appResolver.mirrorURL(for: url)?.absoluteString ?? ""

            XCTAssertTrue(mirrorUrl.hasPrefix(mirrorBase), name)
            XCTAssertTrue(mirrorUrl.hasSuffix("/" + url.lastPathComponent), name)
        }

        for (name, prefix) in pathPrefixes {
            let url = try XCTUnwrap(URL(string: prefix + "file.json"), name)
            let collapsedUrl = try XCTUnwrap(URL(string: (prefix as NSString).appendingPathComponent("file.json")), name)

            for prefixedUrl in [url, collapsedUrl] {
                let mirrorUrl = appResolver.mirrorURL(for: prefixedUrl)?.absoluteString ?? ""

                XCTAssertTrue(mirrorUrl.hasPrefix(mirrorBase), name)
                XCTAssertTrue(mirrorUrl.hasSuffix("/file.json"), name)
            }
        }

        XCTAssertEqual(
            appResolver.mirrorURL(for: config.commonTypesURL)?.absoluteString,
            mirrorBase + "chains/types/default.json"
        )

        let iconUrl = try XCTUnwrap(URL(string: config.whiteAppearanceIconsPath + "DOT.svg"))

        XCTAssertEqual(
            appResolver.mirrorURL(for: iconUrl)?.absoluteString,
            mirrorBase + "icons/tokens/white/v1/DOT.svg"
        )
    }

    func testAppConfigKeepsOtherRepositoriesOnGitHub() {
        let config = ApplicationConfig.shared
        let appResolver = ConfigMirrorURLResolver(applicationConfig: config)

        XCTAssertNil(appResolver.mirrorURL(for: config.inAppUpdatesEntrypointURL))
        XCTAssertNil(appResolver.mirrorURL(for: config.inAppUpdatesChangelogsURL))
        XCTAssertNil(appResolver.mirrorURL(for: config.logoURL))
        XCTAssertNil(appResolver.mirrorURL(for: GovernanceDelegateMetadataFactory.baseUrl.appendingPathComponent("a.json")))
    }

    private func assertMirror(
        of original: String,
        is expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let url = URL(string: original) else {
            XCTFail("Invalid url", file: file, line: line)
            return
        }

        XCTAssertEqual(resolver.mirrorURL(for: url)?.absoluteString, expected, file: file, line: line)
    }

    private func assertNoMirror(of original: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let url = URL(string: original) else {
            XCTFail("Invalid url", file: file, line: line)
            return
        }

        XCTAssertNil(resolver.mirrorURL(for: url), file: file, line: line)
    }
}
