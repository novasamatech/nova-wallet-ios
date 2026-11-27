import XCTest
@testable import novawallet

final class ConfigMirrorAnswerValidatorTests: XCTestCase {
    private let jsonUrl = URL(string: "https://mirror.novatest/v1/config/chains/v23/chains.json")!
    private let upperCaseJsonUrl = URL(string: "https://mirror.novatest/v1/config/chains/v23/CHAINS.JSON")!
    private let iconUrl = URL(string: "https://mirror.novatest/v1/config/icons/DOT.png")!

    private let commit = ConfigMirrorTestAnswer.commitHeaders
    private let json = #"{"source":"mirror"}"#

    func testTellsUsableAnswerFromUnusableOne() {
        typealias Case = (name: String, url: URL, status: Int?, headers: [String: String]?, body: String, expected: String)

        let cases: [Case] = [
            ("json", jsonUrl, 200, commit, json, "nil"),
            ("json array", jsonUrl, 200, commit, "[]", "nil"),
            ("json by upper case extension", upperCaseJsonUrl, 200, commit, json, "nil"),
            ("not json", iconUrl, 200, commit, "png bytes", "nil"),
            ("lower case header name", iconUrl, 200, ["x-config-commit": "abc"], "png bytes", "nil"),
            ("content type is not looked at", jsonUrl, 200, commit.merging(["Content-Type": "text/html"]) { $1 }, json, "nil"),
            ("no file", jsonUrl, 404, nil, #"{"error":"config_not_found"}"#, "unexpectedStatus(Optional(404))"),
            ("not ready", jsonUrl, 503, nil, "", "unexpectedStatus(Optional(503))"),
            ("limit", jsonUrl, 429, nil, "", "unexpectedStatus(Optional(429))"),
            ("redirect", jsonUrl, 302, ["Location": "https://elsewhere.novatest/"], "", "unexpectedStatus(Optional(302))"),
            ("other success status", jsonUrl, 204, commit, json, "unexpectedStatus(Optional(204))"),
            ("not modified", jsonUrl, 304, commit, "", "unexpectedStatus(Optional(304))"),
            ("no response", jsonUrl, nil, nil, json, "unexpectedStatus(nil)"),
            ("page of a network on the way for json", jsonUrl, 200, nil, "<html></html>", "missingCommitHeader"),
            ("page of a network on the way for icon", iconUrl, 200, ["Content-Type": "text/html"], "<html></html>", "missingCommitHeader"),
            ("empty commit", iconUrl, 200, [ConfigMirrorConstants.commitHeader: ""], "png bytes", "missingCommitHeader"),
            ("empty body", jsonUrl, 200, commit, "", "emptyBody"),
            ("empty icon", iconUrl, 200, commit, "", "emptyBody"),
            ("truncated json", jsonUrl, 200, commit, #"[{"chainId":"#, "malformedJson"),
            ("html for json", jsonUrl, 200, commit, "<html></html>", "malformedJson"),
            ("html for upper case json", upperCaseJsonUrl, 200, commit, "<html></html>", "malformedJson")
        ]

        let validator = ConfigMirrorAnswerValidator()

        for testCase in cases {
            let response = testCase.status.map {
                ConfigMirrorTestAnswer.response($0, testCase.url, headers: testCase.headers)
            }

            let failure = validator.validate(response: response, data: Data(testCase.body.utf8), mirrorURL: testCase.url)

            XCTAssertEqual(failure.map { "\($0)" } ?? "nil", testCase.expected, testCase.name)
        }
    }
}
