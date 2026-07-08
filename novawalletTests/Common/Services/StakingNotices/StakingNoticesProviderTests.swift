import XCTest
import Foundation_iOS
@testable import novawallet

// Minimal stub — only what StakingNoticesProvider needs.
private final class StubLocalizationManager: LocalizationManagerProtocol {
    var selectedLocalization: String
    var availableLocalizations: [String]
    private var observers: [(owner: Weak<AnyObject>, queue: DispatchQueue?, closure: LocalizationChangeClosure)] = []

    init(localization: String = "en") {
        selectedLocalization = localization
        availableLocalizations = [localization]
    }

    func addObserver(with owner: AnyObject, queue: DispatchQueue?, closure: @escaping LocalizationChangeClosure) {
        observers.append((Weak(owner), queue, closure))
    }

    func removeObserver(by owner: AnyObject) {
        observers.removeAll { $0.owner.value === owner }
    }

    func simulateChange(from old: String, to new: String) {
        selectedLocalization = new
        observers = observers.filter { $0.owner.value != nil }
        for obs in observers {
            let fire = { obs.closure(old, new) }
            if let q = obs.queue { q.async(execute: fire) } else { fire() }
        }
    }
}

// Tiny weak-box so the stub can hold observers weakly (matching LocalizationManager behaviour).
private struct Weak<T: AnyObject> {
    weak var value: T?
    init(_ v: T) { value = v }
}

final class StakingNoticesProviderTests: XCTestCase {
    private var tempCacheURL: URL!

    override func setUpWithError() throws {
        let tempDir = FileManager.default.temporaryDirectory
        tempCacheURL = tempDir.appendingPathComponent("staking_notices_test_\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempCacheURL)
    }

    func testEmptyOnFirstLaunch() {
        let provider = StakingNoticesProvider(
            url: URL(string: "https://example.com/x.json")!,
            cacheURL: tempCacheURL
        )
        XCTAssertTrue(provider.allNotices.isEmpty)
    }

    func testLoadsCachedFileOnInit() throws {
        let json = """
        [{
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": "Test",
          "longText": "Test long"
        }]
        """.data(using: .utf8)!
        try json.write(to: tempCacheURL)

        let provider = StakingNoticesProvider(
            url: URL(string: "https://example.com/x.json")!,
            cacheURL: tempCacheURL
        )

        // loadFromDisk() is synchronous in init — no drain needed.
        XCTAssertEqual(provider.allNotices.count, 1)
    }

    func testMalformedEntryDoesNotBreakBatch() {
        let json = """
        [
          {"chainId": "bad-entry-missing-fields"},
          {
            "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
            "severity": "info",
            "shortText": "Test",
            "longText": "Test long"
          }
        ]
        """.data(using: .utf8)!
        try? json.write(to: tempCacheURL)

        let provider = StakingNoticesProvider(
            url: URL(string: "https://example.com/x.json")!,
            cacheURL: tempCacheURL
        )

        // loadFromDisk() is synchronous in init — no drain needed.
        XCTAssertEqual(provider.allNotices.count, 1)
    }

    // MARK: - Locale tests

    /// Provider must use LocalizationManager.selectedLocalization, NOT Locale.preferredLanguages.
    /// Regression test for the bug where Spanish UI showed English notice text because
    /// Locale.preferredLanguages returned "en-US" even after Nova's in-app language switch.
    func testUsesLocalizationManagerLocaleNotSystemLocale() throws {
        let json = """
        [{
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": {"en": "English text", "es": "Texto en español"},
          "longText": {"en": "English body", "es": "Cuerpo en español"}
        }]
        """.data(using: .utf8)!
        try json.write(to: tempCacheURL)

        let locManager = StubLocalizationManager(localization: "es")
        let provider = StakingNoticesProvider(
            url: URL(string: "https://example.com/x.json")!,
            cacheURL: tempCacheURL,
            localizationManager: locManager
        )

        let notice = provider.allNotices["70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e"]
        XCTAssertEqual(
            notice?.shortText,
            "Texto en español",
            "Provider must pick locale from LocalizationManager, not Locale.preferredLanguages"
        )
        XCTAssertEqual(notice?.longText, "Cuerpo en español")
    }

    /// When the user switches app language, the provider re-decodes cached JSON and emits
    /// updated notices — no network fetch required.
    func testReDecodesOnLocalizationChange() throws {
        let json = """
        [{
          "chainId": "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e",
          "severity": "info",
          "shortText": {"en": "English text", "ru": "Текст на русском"},
          "longText": {"en": "English body", "ru": "Тело на русском"}
        }]
        """.data(using: .utf8)!
        try json.write(to: tempCacheURL)

        let locManager = StubLocalizationManager(localization: "en")
        let provider = StakingNoticesProvider(
            url: URL(string: "https://example.com/x.json")!,
            cacheURL: tempCacheURL,
            localizationManager: locManager
        )

        let chainId = "70255b4d28de0fc4e1a193d7e175ad1ccef431598211c55538f1018651a0344e"
        XCTAssertEqual(provider.allNotices[chainId]?.shortText, "English text")

        // Simulate in-app language switch: observer fires on .main
        let expectation = self.expectation(description: "notice updated to Russian")
        provider.subscribe(self) {
            if provider.allNotices[chainId]?.shortText == "Текст на русском" {
                expectation.fulfill()
            }
        }
        locManager.simulateChange(from: "en", to: "ru")

        waitForExpectations(timeout: 1.0)
    }
}
