import XCTest
@testable import novawallet

final class AnnouncementsRemoteTests: XCTestCase {
    func testLinkIsDecodedWithLocalizedTitle() throws {
        let announcement = try decodeSingle(
            """
            {
              "staking": [{
                "style": "warning",
                "description": { "default": "Some options were removed" },
                "link": {
                  "url": "https://docs.novawallet.io/removed",
                  "title": { "default": "Learn more", "ru": "Подробнее" }
                }
              }]
            }
            """
        )

        let link = try XCTUnwrap(announcement.link)

        XCTAssertEqual(link.url, URL(string: "https://docs.novawallet.io/removed"))
        XCTAssertEqual(link.title(for: Locale(identifier: "ru")), "Подробнее")
        XCTAssertEqual(link.title(for: Locale(identifier: "fr")), "Learn more")
        XCTAssertEqual(link.title(for: Locale(identifier: "en")), "Learn more")
    }

    func testAnnouncementWithoutLinkHasNilLink() throws {
        let announcement = try decodeSingle(
            """
            {
              "staking": [{
                "style": "info",
                "description": { "default": "Plain message" }
              }]
            }
            """
        )

        XCTAssertNil(announcement.link)
        XCTAssertEqual(announcement.message(for: Locale(identifier: "en")), "Plain message")
    }

    func testLinkWithInvalidUrlIsDroppedButAnnouncementKept() throws {
        let announcement = try decodeSingle(
            """
            {
              "staking": [{
                "style": "info",
                "description": { "default": "Plain message" },
                "link": { "url": "not a url", "title": { "default": "Learn more" } }
              }]
            }
            """
        )

        XCTAssertNil(announcement.link)
        XCTAssertEqual(announcement.message(for: Locale(identifier: "en")), "Plain message")
    }

    func testLinkWithMissingUrlIsDropped() throws {
        let announcement = try decodeSingle(
            """
            {
              "staking": [{
                "style": "info",
                "description": { "default": "Plain message" },
                "link": { "title": { "default": "Learn more" } }
              }]
            }
            """
        )

        XCTAssertNil(announcement.link)
    }

    func testLinkWithoutUsableTitleIsDropped() throws {
        let announcement = try decodeSingle(
            """
            {
              "staking": [{
                "style": "info",
                "description": { "default": "Plain message" },
                "link": { "url": "https://docs.novawallet.io/removed", "title": {} }
              }]
            }
            """
        )

        XCTAssertNil(announcement.link)
    }

    func testLinkTitleFallsBackToDefaultWhenLocaleMissing() throws {
        let announcement = try decodeSingle(
            """
            {
              "staking": [{
                "style": "info",
                "description": { "default": "Plain message" },
                "link": { "url": "https://docs.novawallet.io/removed", "title": { "ru": "Подробнее" } }
              }]
            }
            """
        )

        let link = try XCTUnwrap(announcement.link)

        XCTAssertEqual(link.title(for: Locale(identifier: "ru")), "Подробнее")
        XCTAssertNil(link.title(for: Locale(identifier: "en")))
    }

    private func decodeSingle(_ json: String) throws -> Announcement {
        let data = try XCTUnwrap(json.data(using: .utf8))
        let remote = try JSONDecoder().decode(AnnouncementsRemote.self, from: data)
        let announcements = remote.announcements(for: .staking)

        XCTAssertEqual(announcements.count, 1)

        return try XCTUnwrap(announcements.first)
    }
}
