import XCTest
@testable import novawallet

final class AnnouncementsMapperTests: XCTestCase {
    private let polkadotChainId = "0x91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
    private let kusamaChainId = "0xb0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"

    // MARK: - Localization

    func testMessageReturnsTranslationMatchingLocaleLanguage() throws {
        let json = """
        {
          "staking": [
            {
              "style": "info",
              "description": { "default": "Default text", "ru": "Русский текст" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertEqual(announcements[0].message(for: Locale(identifier: "ru")), "Русский текст")
    }

    func testMessageFallsBackToDefaultForMissingLanguage() throws {
        let json = """
        {
          "staking": [
            {
              "style": "info",
              "description": { "default": "Default text", "ru": "Русский текст" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertEqual(announcements[0].message(for: Locale(identifier: "fr")), "Default text")
    }

    func testMessageUsesDefaultWhenEnglishKeyAbsent() throws {
        let json = """
        {
          "staking": [
            {
              "style": "info",
              "description": { "default": "Default text", "ru": "Русский текст" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)

        XCTAssertEqual(announcements[0].message(for: Locale(identifier: "en")), "Default text")
    }

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

    // MARK: - View model factory

    func testViewModelFactoryMapsOnlyUsableTranslations() throws {
        // given
        let json = """
        {
          "staking": [
            {
              "style": "warning",
              "description": { "ru": "Русский текст" }
            }
          ]
        }
        """

        let announcements = try decodeStakingAnnouncements(from: json)
        let factory = AnnouncementViewModelFactory()

        // when
        let englishViewModel = factory.createViewModel(
            from: announcements[0],
            locale: Locale(identifier: "en")
        )
        let russianViewModel = factory.createViewModel(
            from: announcements[0],
            locale: Locale(identifier: "ru")
        )

        // then
        XCTAssertNil(englishViewModel)
        XCTAssertEqual(
            russianViewModel,
            AnnouncementViewModel(style: .warning, message: "Русский текст")
        )
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

        XCTAssertEqual(
            announcements.map { $0.message(for: Locale(identifier: "en")) },
            ["First", "Second", "Third"]
        )
        XCTAssertEqual(announcements.map(\.style), [.info, .warning, .error])
    }

    // MARK: - Array helpers

    func testGeneralOnlyKeepsAnnouncementsWithoutChainId() {
        let general = makeAnnouncement(message: "General")
        let chainSpecific = makeAnnouncement(chainId: polkadotChainId, message: "Chain")

        XCTAssertEqual([general, chainSpecific, general].generalOnly(), [general, general])
    }

    func testGroupedByChainKeepsFirstAnnouncementPerChain() {
        let polkadotFirst = makeAnnouncement(chainId: polkadotChainId, message: "Polkadot first")
        let polkadotSecond = makeAnnouncement(chainId: polkadotChainId, message: "Polkadot second")
        let kusama = makeAnnouncement(chainId: kusamaChainId, message: "Kusama")
        let general = makeAnnouncement(message: "General")

        let grouped = [general, polkadotFirst, kusama, polkadotSecond].groupedByChain()

        XCTAssertEqual(grouped, [polkadotChainId: polkadotFirst, kusamaChainId: kusama])
    }

    func testFirstAnnouncementReturnsFirstForChainAndNilOtherwise() {
        let general = makeAnnouncement(message: "General")
        let polkadotFirst = makeAnnouncement(chainId: polkadotChainId, message: "Polkadot first")
        let polkadotSecond = makeAnnouncement(chainId: polkadotChainId, message: "Polkadot second")

        let announcements = [general, polkadotFirst, polkadotSecond]

        XCTAssertEqual(announcements.firstAnnouncement(for: polkadotChainId), polkadotFirst)
        XCTAssertNil(announcements.firstAnnouncement(for: kusamaChainId))
    }

    // MARK: - Private

    private func decodeStakingAnnouncements(from json: String) throws -> [Announcement] {
        let remote = try JSONDecoder().decode(
            AnnouncementsRemote.self,
            from: Data(json.utf8)
        )

        return remote.announcements(for: .staking)
    }

    private func makeAnnouncement(
        chainId: ChainModel.Id? = nil,
        message: String
    ) -> Announcement {
        Announcement(
            chainId: chainId,
            style: .info,
            content: [Announcement.defaultContentKey: message]
        )
    }
}
