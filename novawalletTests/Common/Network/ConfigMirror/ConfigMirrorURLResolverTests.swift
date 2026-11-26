import XCTest
@testable import novawallet

final class ConfigMirrorURLResolverTests: XCTestCase {
    private let gitHub = "https://raw.githubusercontent.com/novasamatech"
    private let mirror = "https://mirror.novatest/v1/config"

    private let resolver = ConfigMirrorURLResolver(
        mirrorBaseURL: URL(string: "https://mirror.novatest/v1/config/")!,
        sources: [
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/")!,
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/")!
        ]
    )

    func testMapsBothMasterFormsKeepingPathAsIs() throws {
        let mapping = [
            "\(gitHub)/nova-utils/master/chains/v23/chains.json": "\(mirror)/chains/v23/chains.json",
            "\(gitHub)/nova-utils/refs/heads/master/legal/v1/documents.json": "\(mirror)/legal/v1/documents.json",
            "\(gitHub)/nova-utils/master/chains/v23/preConfigured/details/0xabc.json":
                "\(mirror)/chains/v23/preConfigured/details/0xabc.json",
            "\(gitHub)/nova-utils/master/icons/My%20Token%2B1%25.svg": "\(mirror)/icons/My%20Token%2B1%25.svg",
            "\(gitHub)/nova-utils/master/icons/v1.0/..hidden/a.b..svg": "\(mirror)/icons/v1.0/..hidden/a.b..svg",
            "\(gitHub)/nova-utils/master/icons//DOT.svg": "\(mirror)/icons//DOT.svg"
        ]

        for (original, expected) in mapping {
            let url = try XCTUnwrap(URL(string: original))

            XCTAssertEqual(resolver.mirrorURL(for: url)?.absoluteString, expected)
        }
    }

    func testLeavesQueryAndFragmentBehind() throws {
        let originals = [
            "\(gitHub)/nova-utils/master/chains/v23/chains.json?token=abc&v=1",
            "\(gitHub)/nova-utils/master/chains/v23/chains.json#section",
            "\(gitHub)/nova-utils/master/chains/v23/chains.json?token=abc#section",
            "\(gitHub)/nova-utils/master/chains/v23/chains.json?path=../../x"
        ]

        for original in originals {
            let url = try XCTUnwrap(URL(string: original))

            XCTAssertEqual(resolver.mirrorURL(for: url)?.absoluteString, "\(mirror)/chains/v23/chains.json", original)
        }
    }

    func testLeavesEverythingElseWhereItIs() throws {
        // the last url is what string path helpers make of a url: one slash after the scheme and no host
        let collapsedUrl = ("\(gitHub)/nova-utils/master/banners/v2/" as NSString).appendingPathComponent("banners.json")

        XCTAssertTrue(collapsedUrl.hasPrefix("https:/raw.githubusercontent.com"))

        let notMirrored = [
            "\(gitHub)/nova-wallet-ios-releases/master/updates/v1/entrypoint_dev.json",
            "\(gitHub)/nova-utils-fork/master/chains/v23/chains.json",
            "https://raw.githubusercontent.com/other/nova-utils/master/chains/v23/chains.json",
            "\(gitHub)/nova-utils/develop/chains/v23/chains.json",
            "\(gitHub)/nova-utils/refs/heads/develop/chains/v23/chains.json",
            "\(gitHub)/nova-utils/master-next/chains/v23/chains.json",
            "\(gitHub)/nova-utils/master/",
            "\(gitHub)/nova-utils/master",
            "https://evil.example/raw.githubusercontent.com/novasamatech/nova-utils/master/chains.json",
            "https://raw.githubusercontent.com.evil.example/novasamatech/nova-utils/master/chains.json",
            "https://evil.example/?https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains.json",
            "https://raw.githubusercontent.com@evil.example/novasamatech/nova-utils/master/chains.json",
            "https://user@raw.githubusercontent.com/novasamatech/nova-utils/master/chains.json",
            "https://user:password@raw.githubusercontent.com/novasamatech/nova-utils/master/chains.json",
            "https://raw.githubusercontent.com:8443/novasamatech/nova-utils/master/chains.json",
            "https://RAW.githubusercontent.com/novasamatech/nova-utils/master/chains.json",
            "HTTPS://raw.githubusercontent.com/novasamatech/nova-utils/master/chains.json",
            "http://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v23/chains.json",
            "\(mirror)/chains/v23/chains.json",
            collapsedUrl
        ]

        for original in notMirrored {
            let url = try XCTUnwrap(URL(string: original))

            XCTAssertNil(resolver.mirrorURL(for: url), original)
        }
    }

    func testLeavesOnGitHubPathWithDotSegment() throws {
        let files = [
            "../secret.json",
            "chains/../../secret.json",
            "chains/..",
            "chains/../",
            "./chains.json",
            "chains/./chains.json",
            "chains/.",
            "%2e%2e/secret.json",
            "chains/%2E%2E/secret.json",
            "chains/.%2e/secret.json",
            "chains/%2e./secret.json",
            "chains/%2e/chains.json",
            "chains%2F..%2Fsecret.json",
            "chains/..%2Fsecret.json",
            "%2e%2e%2fsecret.json"
        ]

        for file in files {
            for directory in ["nova-utils/master/", "nova-utils/refs/heads/master/"] {
                let url = try XCTUnwrap(URL(string: "\(gitHub)/\(directory)\(file)"))

                XCTAssertNil(resolver.mirrorURL(for: url), file)
            }
        }
    }

    func testSourceThatIsNotDirectoryIsIgnored() throws {
        let looseResolver = ConfigMirrorURLResolver(
            mirrorBaseURL: URL(string: "https://mirror.novatest/v1/config/")!,
            sources: [URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master")!]
        )

        for file in ["master/chains.json", "master-next/chains.json"] {
            let url = try XCTUnwrap(URL(string: "\(gitHub)/nova-utils/\(file)"))

            XCTAssertNil(looseResolver.mirrorURL(for: url), file)
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

        // the two ways the app completes these prefixes
        for prefix in pathPrefixes {
            try urls.append(XCTUnwrap(URL(string: prefix + "file.json")))
            try urls.append(XCTUnwrap(URL(string: prefix)).appendingPathComponent("file.json"))
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
