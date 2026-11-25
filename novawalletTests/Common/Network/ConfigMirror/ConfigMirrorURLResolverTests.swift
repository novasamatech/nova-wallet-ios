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

    func testAppConfigCoversBothGitHubFormsOfEveryConfiguredUrl() throws {
        let config = ApplicationConfig.shared
        let appResolver = ConfigMirrorURLResolver(applicationConfig: config)
        let mirrorBase = config.configMirrorBaseURL.absoluteString

        XCTAssertTrue(mirrorBase.hasSuffix("/v1/config/"))

        XCTAssertEqual(
            appResolver.mirrorURL(for: config.commonTypesURL)?.absoluteString,
            mirrorBase + "chains/types/default.json"
        )

        let iconUrl = try XCTUnwrap(URL(string: config.whiteAppearanceIconsPath + "DOT.svg"))

        XCTAssertEqual(
            appResolver.mirrorURL(for: iconUrl)?.absoluteString,
            mirrorBase + "icons/tokens/white/v1/DOT.svg"
        )

        XCTAssertNil(appResolver.mirrorURL(for: config.inAppUpdatesEntrypointURL))
        XCTAssertNil(appResolver.mirrorURL(for: config.logoURL))
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
