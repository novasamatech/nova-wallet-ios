import XCTest
@testable import novawallet

final class StakingNoticeDecodingTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDecodesV1PlainStringSchema() throws {
        let json = """
        {
          "chainId": "f3c7ad88f6a80f366c4be216691411ef0622e8b809b1c4b2599b87487420976a",
          "severity": "critical",
          "shortText": "Migrate by Aug 1, 2026",
          "longText": "The Manta Atlantic parachain slot expires August 1, 2026.",
          "endDate": "2026-08-01"
        }
        """.data(using: .utf8)!

        let notice = try decoder.decode(StakingNotice.self, from: json)

        XCTAssertEqual(notice.severity, .critical)
        XCTAssertEqual(notice.shortText, "Migrate by Aug 1, 2026")
        XCTAssertEqual(notice.longText, "The Manta Atlantic parachain slot expires August 1, 2026.")
        XCTAssertNotNil(notice.endDate)
    }

    func testDecodesV2LocaleMapSchemaFallsBackToEnglish() throws {
        let json = """
        {
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": {"en": "Validator program update", "ru": "Обновление программы валидаторов"},
          "longText": {"en": "Rewards may pause briefly.", "ru": "Награды могут приостановиться."}
        }
        """.data(using: .utf8)!

        let notice = try decoder.decode(StakingNotice.self, from: json)

        XCTAssertEqual(notice.shortText, "Validator program update")
        XCTAssertEqual(notice.longText, "Rewards may pause briefly.")
    }

    func testDecodesV2LocaleMapPicksPreferredLocale() throws {
        let json = """
        {
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": {"en": "Validator program update", "ru": "Обновление программы валидаторов"},
          "longText": {"en": "Rewards may pause briefly.", "ru": "Награды могут приостановиться."}
        }
        """.data(using: .utf8)!

        let localized = JSONDecoder()
        localized.userInfo[.stakingNoticePreferredLocale] = "ru_RU"

        let notice = try localized.decode(StakingNotice.self, from: json)

        XCTAssertEqual(notice.shortText, "Обновление программы валидаторов")
        XCTAssertEqual(notice.longText, "Награды могут приостановиться.")
    }

    func testDecodesV2LocaleMapFallsBackToLanguageWhenRegionMissing() throws {
        let json = """
        {
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": {"en": "Update", "pt": "Atualização"},
          "longText": {"en": "Body.", "pt": "Corpo."}
        }
        """.data(using: .utf8)!

        let localized = JSONDecoder()
        // Preferred is pt_PT (Portugal) but the map only has the generic `pt` key —
        // parser should strip the region and find `pt`.
        localized.userInfo[.stakingNoticePreferredLocale] = "pt_PT"

        let notice = try localized.decode(StakingNotice.self, from: json)

        XCTAssertEqual(notice.shortText, "Atualização")
        XCTAssertEqual(notice.longText, "Corpo.")
    }

    func testDecodesV2LocaleMapFallsBackToEnglishWhenPreferredAbsent() throws {
        let json = """
        {
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": {"en": "Update", "ru": "Обновление"},
          "longText": {"en": "Body.", "ru": "Тело."}
        }
        """.data(using: .utf8)!

        let localized = JSONDecoder()
        // Preferred is Japanese but the map only has en/ru — should fall back to en.
        localized.userInfo[.stakingNoticePreferredLocale] = "ja_JP"

        let notice = try localized.decode(StakingNotice.self, from: json)

        XCTAssertEqual(notice.shortText, "Update")
        XCTAssertEqual(notice.longText, "Body.")
    }

    func testEndDateIsOptional() throws {
        let json = """
        {
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": "x",
          "longText": "y"
        }
        """.data(using: .utf8)!

        let notice = try decoder.decode(StakingNotice.self, from: json)
        XCTAssertNil(notice.endDate)
    }

    func testRejectsLocaleMapWithoutEnglishFallback() {
        let json = """
        {
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": {"ru": "Привет"},
          "longText": "y"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(StakingNotice.self, from: json))
    }

    func testRejectsInvalidEndDate() {
        let json = """
        {
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": "x",
          "longText": "y",
          "endDate": "next Friday"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(StakingNotice.self, from: json))
    }

    func testRejectsUnknownSeverity() {
        let json = """
        {
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "urgent",
          "shortText": "x",
          "longText": "y"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(StakingNotice.self, from: json))
    }
}
