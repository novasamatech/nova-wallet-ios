import XCTest
@testable import novawallet

final class AnnouncementViewModelFactoryTests: XCTestCase {
    private let polkadotChainId = "0x91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
    private let kusamaChainId = "0xb0a8d493285c2df73290dfb7e61f870f17b41801197a149ca93654499ea3dafe"

    private let factory = AnnouncementViewModelFactory()

    // MARK: - Localization

    func testMessageUsesTranslationMatchingLocaleLanguage() {
        let announcement = makeAnnouncement(
            content: ["default": "Default text", "ru": "Русский текст"]
        )

        let viewModel = factory.createViewModel(from: announcement, locale: Locale(identifier: "ru"))

        XCTAssertEqual(viewModel?.message, "Русский текст")
    }

    func testMessageFallsBackToDefaultForMissingLanguage() {
        let announcement = makeAnnouncement(
            content: ["default": "Default text", "ru": "Русский текст"]
        )

        XCTAssertEqual(
            factory.createViewModel(from: announcement, locale: Locale(identifier: "fr"))?.message,
            "Default text"
        )
        XCTAssertEqual(
            factory.createViewModel(from: announcement, locale: Locale(identifier: "en"))?.message,
            "Default text"
        )
    }

    func testAnnouncementWithoutUsableTranslationGivesNoViewModel() {
        let announcement = makeAnnouncement(style: .warning, content: ["ru": "Русский текст"])

        XCTAssertNil(factory.createViewModel(from: announcement, locale: Locale(identifier: "en")))
        XCTAssertEqual(
            factory.createViewModel(from: announcement, locale: Locale(identifier: "ru")),
            AnnouncementViewModel(style: .warning, message: "Русский текст")
        )
    }

    func testStyleIsMappedToAlertStyle() {
        let locale = Locale(identifier: "en")

        XCTAssertEqual(
            factory.createViewModel(from: makeAnnouncement(style: .info, message: "1"), locale: locale)?.style,
            .info
        )
        XCTAssertEqual(
            factory.createViewModel(from: makeAnnouncement(style: .warning, message: "2"), locale: locale)?.style,
            .warning
        )
        XCTAssertEqual(
            factory.createViewModel(from: makeAnnouncement(style: .error, message: "3"), locale: locale)?.style,
            .error
        )
    }

    // MARK: - General

    func testGeneralViewModelsKeepOnlyResolvableAnnouncementsWithoutChainId() {
        let general = makeAnnouncement(message: "General")
        let untranslatable = makeAnnouncement(content: ["ru": "Только русский"])
        let chainSpecific = makeAnnouncement(chainId: polkadotChainId, message: "Chain")

        let viewModels = factory.createGeneralViewModels(
            from: [general, untranslatable, chainSpecific],
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(viewModels.map(\.message), ["General"])
    }

    // MARK: - Per chain

    func testChainViewModelPicksFirstAnnouncementOfChain() {
        let general = makeAnnouncement(message: "General")
        let polkadotFirst = makeAnnouncement(chainId: polkadotChainId, message: "Polkadot first")
        let polkadotSecond = makeAnnouncement(chainId: polkadotChainId, message: "Polkadot second")

        let viewModel = factory.createChainViewModel(
            from: [general, polkadotFirst, polkadotSecond],
            chainId: polkadotChainId,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(viewModel?.message, "Polkadot first")
    }

    func testChainViewModelFallsThroughToNextEntryWhenFirstIsUntranslatable() {
        let untranslatable = makeAnnouncement(chainId: polkadotChainId, content: ["ru": "Только русский"])
        let translatable = makeAnnouncement(chainId: polkadotChainId, message: "Fallback")

        let viewModel = factory.createChainViewModel(
            from: [untranslatable, translatable],
            chainId: polkadotChainId,
            locale: Locale(identifier: "en")
        )

        XCTAssertEqual(viewModel?.message, "Fallback")
    }

    func testChainViewModelIgnoresGeneralAndOtherChainAnnouncements() {
        let general = makeAnnouncement(message: "General")
        let kusama = makeAnnouncement(chainId: kusamaChainId, message: "Kusama")

        let viewModel = factory.createChainViewModel(
            from: [general, kusama],
            chainId: polkadotChainId,
            locale: Locale(identifier: "en")
        )

        XCTAssertNil(viewModel)
    }

    // MARK: - Private

    private func makeAnnouncement(
        chainId: ChainModel.Id? = nil,
        style: Announcement.Style = .info,
        message: String
    ) -> Announcement {
        makeAnnouncement(
            chainId: chainId,
            style: style,
            content: [Announcement.defaultContentKey: message]
        )
    }

    private func makeAnnouncement(
        chainId: ChainModel.Id? = nil,
        style: Announcement.Style = .info,
        content: [String: String]
    ) -> Announcement {
        Announcement(
            chainId: chainId,
            style: style,
            content: content
        )
    }
}
