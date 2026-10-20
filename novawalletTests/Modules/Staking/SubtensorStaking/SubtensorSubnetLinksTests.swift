@testable import novawallet
import XCTest

final class SubtensorSubnetLinksTests: XCTestCase {
    private typealias Normalizer = SubtensorSubnetLinkNormalizer

    func testWebsiteKeepsHttpsAndHttpUrls() {
        XCTAssertEqual(Normalizer.website(from: "https://engy.ai"), URL(string: "https://engy.ai"))
        XCTAssertEqual(Normalizer.website(from: "http://hotfloat.io"), URL(string: "http://hotfloat.io"))
    }

    func testWebsiteGetsHttpsWhenTheSchemeIsMissing() {
        XCTAssertEqual(Normalizer.website(from: "blockmachine.io"), URL(string: "https://blockmachine.io"))
        XCTAssertEqual(Normalizer.website(from: "  www.affine.io \n"), URL(string: "https://www.affine.io"))
        XCTAssertEqual(Normalizer.website(from: "ByteLeap.ai"), URL(string: "https://ByteLeap.ai"))
    }

    func testWebsiteRejectsTextThatIsNotAnHttpUrl() {
        let junk: [String?] = [
            nil, "", "   ", "not a url", "ByteLeap", "ftp://files.example", "https://", "mailto:hi@example.com"
        ]

        for raw in junk {
            XCTAssertNil(Normalizer.website(from: raw), raw ?? "nil")
        }
    }

    func testGithubAcceptsOwnerAndRepositoryOnly() {
        XCTAssertEqual(
            Normalizer.github(from: "https://github.com/hanlinai/engy"),
            URL(string: "https://github.com/hanlinai/engy")
        )
        XCTAssertEqual(
            Normalizer.github(from: "https://github.com/taostat/blockmachine/"),
            URL(string: "https://github.com/taostat/blockmachine")
        )
        XCTAssertEqual(Normalizer.github(from: "github.com/macrocosm-os"), URL(string: "https://github.com/macrocosm-os"))
        XCTAssertEqual(Normalizer.github(from: "http://www.github.com/a/b"), URL(string: "https://github.com/a/b"))
        XCTAssertEqual(
            Normalizer.github(from: "https://github.com/a/b/tree/main"),
            URL(string: "https://github.com/a/b")
        )
    }

    func testGithubRejectsOtherHostsAndMissingOwner() {
        let junk: [String?] = [nil, "", "https://gitlab.com/a/b", "https://github.com", "a/b"]

        for raw in junk {
            XCTAssertNil(Normalizer.github(from: raw), raw ?? "nil")
        }
    }

    func testLinksPreferSubnetUrlAndFallBackToSubnetWebsite() {
        let preferred = SubtensorSubnetLinks(
            subnetUrl: "https://chutes.ai",
            subnetWebsite: "https://other.example",
            githubRepo: ""
        )
        XCTAssertEqual(preferred.website, URL(string: "https://chutes.ai"))
        XCTAssertNil(preferred.github)

        let fallback = SubtensorSubnetLinks(subnetUrl: "", subnetWebsite: "chutes.ai", githubRepo: nil)
        XCTAssertEqual(fallback.website, URL(string: "https://chutes.ai"))

        XCTAssertEqual(SubtensorSubnetLinks(subnetUrl: nil, subnetWebsite: nil, githubRepo: nil), .empty)
    }

    func testDisplayTextsDropSchemeAndTrailingSlash() throws {
        let website = try XCTUnwrap(URL(string: "https://chutes.ai/"))
        let websiteWithPath = try XCTUnwrap(URL(string: "http://tag101.ai/app"))
        let github = try XCTUnwrap(URL(string: "https://github.com/chutesai/chutes"))

        XCTAssertEqual(Normalizer.websiteDisplayText(website), "chutes.ai")
        XCTAssertEqual(Normalizer.websiteDisplayText(websiteWithPath), "tag101.ai/app")
        XCTAssertEqual(Normalizer.githubDisplayText(github), "chutesai/chutes")
    }
}
