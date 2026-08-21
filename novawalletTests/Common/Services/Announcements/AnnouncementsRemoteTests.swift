import XCTest
@testable import novawallet

final class AnnouncementsRemoteTests: XCTestCase {
    private let polkadotChainId = "0x91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"

    // MARK: - Style

    func testStyleIsParsedCaseInsensitively() throws {
        let json = """
        {
          "staking": [
            {
              "style": "WARNING",
              "description": { "default": "Warning text" }
            },
            {
              "style": "Error",
              "description": { "default": "Error text" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertEqual(announcements[0].style, .warning)
        XCTAssertEqual(announcements[1].style, .error)
    }

    func testUnknownOrAbsentStyleFallsBackToInfo() throws {
        let json = """
        {
          "staking": [
            {
              "style": "shiny",
              "description": { "default": "Unknown style" }
            },
            {
              "description": { "default": "No style" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertEqual(announcements[0].style, .info)
        XCTAssertEqual(announcements[1].style, .info)
    }

    // MARK: - Chain id

    func testChainIdIsCarriedOver() throws {
        let json = """
        {
          "staking": [
            {
              "chainId": "\(polkadotChainId)",
              "style": "info",
              "description": { "default": "Chain specific" }
            },
            {
              "style": "info",
              "description": { "default": "General" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertEqual(announcements[0].chainId, polkadotChainId)
        XCTAssertNil(announcements[1].chainId)
    }

    // MARK: - Invalid entries

    func testEntryWithMissingOrEmptyDescriptionIsSkipped() throws {
        let json = """
        {
          "staking": [
            {
              "style": "warning"
            },
            {
              "style": "error",
              "description": {}
            },
            {
              "style": "info",
              "description": { "default": "Valid" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertEqual(announcements.count, 1)
        XCTAssertEqual(announcements[0].content, ["default": "Valid"])
    }

    func testNullElementInSectionIsSkipped() throws {
        let json = """
        {
          "staking": [
            null,
            {
              "style": "info",
              "description": { "default": "Valid" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertEqual(announcements.count, 1)
        XCTAssertEqual(announcements[0].content, ["default": "Valid"])
    }

    func testAbsentSectionYieldsEmptyList() throws {
        let json = """
        {
          "governance": [
            {
              "style": "info",
              "description": { "default": "Other section" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertTrue(announcements.isEmpty)
    }

    func testMultipleEntriesAreMappedPreservingOrder() throws {
        let json = """
        {
          "staking": [
            {
              "style": "info",
              "description": { "default": "First" }
            },
            {
              "style": "warning",
              "description": { "default": "Second" }
            },
            {
              "style": "error",
              "description": { "default": "Third" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertEqual(announcements.map { $0.content["default"] }, ["First", "Second", "Third"])
        XCTAssertEqual(announcements.map(\.style), [.info, .warning, .error])
    }

    // MARK: - Private

    private func decodeStakingAnnouncements(from json: String) throws -> [Announcement] {
        let remote = try JSONDecoder().decode(
            AnnouncementsRemote.self,
            from: Data(json.utf8)
        )

        return remote.announcements(for: .staking)
    }
}
