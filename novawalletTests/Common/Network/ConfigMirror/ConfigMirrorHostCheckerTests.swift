import XCTest
@testable import novawallet

final class ConfigMirrorHostCheckerTests: XCTestCase {
    private let mirrorBaseURL = URL(string: "https://nova-infra.novatest/v1/config/")!

    func testReportsOnlyHostThatDiffersFromMirrorOne() throws {
        let cases: [(infraUrl: String, isReported: Bool)] = [
            ("https://nova-infra.novatest/", false),
            ("https://nova-infra.novatest", false),
            ("https://NOVA-INFRA.novatest/v2/", false),
            ("https://nova-infra-dev.novatest/", true),
            ("https://novatest/", true),
            ("https://nova-infra.novatest.example/", true)
        ]

        for testCase in cases {
            let logger = ConfigMirrorLoggerSpy()
            let checker = ConfigMirrorHostChecker(mirrorBaseURL: mirrorBaseURL, logger: logger)

            try checker.check(infraUrl: XCTUnwrap(URL(string: testCase.infraUrl)))

            XCTAssertEqual(logger.errors.count, testCase.isReported ? 1 : 0, testCase.infraUrl)
            XCTAssertTrue(logger.warnings.isEmpty, testCase.infraUrl)
        }
    }
}
