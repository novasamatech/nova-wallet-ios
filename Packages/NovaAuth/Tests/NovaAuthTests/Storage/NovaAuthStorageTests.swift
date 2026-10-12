import XCTest
import Security
import Keystore_iOS
@testable import NovaAuth

final class NovaAuthStorageTests: XCTestCase {
    func testSettingsRoundTripAndResetRetainsGenerationWithoutBearer() throws {
        let settings = InMemorySettingsManager()
        let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
        XCTAssertNil(try store.load())
        settings.set(value: "old-client", for: "gatewayAttestationClientId")
        settings.set(value: "wallet-secret-sentinel", for: "unrelated-wallet")
        let identity = NovaAuthInstallationIdentity(
            clientID: FoundationFixture.clientID,
            keyID: FoundationFixture.keyID,
            registration: .registered
        )
        let state = NovaAuthInstallationState(version: 1, context: try FoundationFixture.context(), requiresUserAction: false, identity: identity)
        try store.save(state)
        XCTAssertTrue(try store.load() == state)
        let reset = NovaAuthInstallationState(
            version: 1,
            context: NovaAuthContext(origin: try FoundationFixture.origin(), generation: 2),
            requiresUserAction: true,
            identity: nil
        )
        try store.save(reset)
        XCTAssertTrue(try store.load() == reset)
        XCTAssertEqual(settings.string(for: "unrelated-wallet"), "wallet-secret-sentinel")
        XCTAssertEqual(settings.string(for: "gatewayAttestationClientId"), "old-client")
        let raw = try XCTUnwrap(settings.data(for: NovaAuthSettingsIdentityStore.storageKey))
        XCTAssertFalse(String(decoding: raw, as: UTF8.self).contains("accessToken"))
    }

    func testSettingsCorruptionAndFailedWriteFailClosed() throws {
        let settings = InMemorySettingsManager()
        let store = NovaAuthSettingsIdentityStore(settingsManager: settings)
        settings.set(value: "wrong-type", for: NovaAuthSettingsIdentityStore.storageKey)
        XCTAssertThrowsError(try store.load())
        settings.set(value: Data("malformed".utf8), for: NovaAuthSettingsIdentityStore.storageKey)
        XCTAssertThrowsError(try store.load())
        let state = NovaAuthInstallationState(version: 1, context: try FoundationFixture.context(), requiresUserAction: false, identity: nil)
        let failing = NovaAuthSettingsIdentityStore(settingsManager: DroppingSettings())
        XCTAssertThrowsError(try failing.save(state)) { XCTAssertEqual($0 as? NovaAuthError, .storageUnavailable) }
    }

    func testKeychainEveryQueryIsScopedAndRecordAndFingerprintAreWrittenTogether() throws {
        let security = FoundationTestSecurity()
        let store = try makeStore(security: security)
        let record = try FoundationFixture.record()
        XCTAssertNil(try store.load())
        try store.replace(record)
        XCTAssertEqual(try store.load(), record)
        try store.replace(FoundationFixture.record(token: "replacement"))
        XCTAssertFalse(try store.remove(ifMatching: record))
        try store.removeAll()
        XCTAssertEqual(security.events.filter { $0.0 == "add" }.count, 1)
        for (_, query) in security.events {
            XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
            XCTAssertEqual(query[kSecAttrService as String] as? String, "io.novawallet.novaauth.profile3.io.nova.wallet")
            XCTAssertEqual(query[kSecAttrAccount as String] as? String, "current")
            XCTAssertEqual(query[kSecAttrAccessGroup as String] as? String, "group.test.novaauth")
            XCTAssertNil(query[kSecAttrSynchronizable as String])
        }
        for attributes in security.attributes {
            XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
            XCTAssertNotNil(attributes[kSecValueData as String] as? Data)
            XCTAssertEqual((attributes[kSecAttrGeneric as String] as? Data)?.count, 32)
        }
    }

    func testReplacementAtDeleteBoundarySurvivesOldExtensionRejection() throws {
        let security = FoundationTestSecurity()
        let main = try makeStore(security: security)
        let reader = try makeStore(security: security)
        let old = try FoundationFixture.record()
        let new = try FoundationFixture.record(token: "new-synthetic-token")
        try main.replace(old)
        let sent = try XCTUnwrap(reader.load())
        security.beforeDelete = { try main.replace(new) }
        XCTAssertFalse(try reader.remove(ifMatching: sent))
        XCTAssertEqual(try main.load(), new)
        XCTAssertTrue(try reader.remove(ifMatching: new))
        XCTAssertNil(try main.load())
    }

    func testCorruptSnapshotNeverDeletesReplacementAndDeniedReadNeverDeletes() throws {
        let security = FoundationTestSecurity()
        let store = try makeStore(security: security)
        let new = try FoundationFixture.record(token: "new-synthetic-token")
        try store.replace(FoundationFixture.record())
        security.setData(Data("malformed".utf8), matching: try XCTUnwrap(security.events.last?.1))
        security.afterCopy = { try store.replace(new) }
        XCTAssertNil(try store.load())
        XCTAssertEqual(try store.load(), new)
        XCTAssertFalse(security.events.contains { $0.0 == "delete" })
        security.events.removeAll()
        security.readStatus = errSecInteractionNotAllowed
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(security.events.map(\.0), ["copy"])
    }

    func testLegacyRecordRemainsReadableButOldRemovalCannotEraseTaggedRenewal() throws {
        let security = FoundationTestSecurity()
        let store = try makeStore(security: security)
        let record = try FoundationFixture.record()
        try store.replace(record)
        let query = try XCTUnwrap(security.events.last?.1)
        security.clearFingerprint(matching: query)
        XCTAssertEqual(try store.load(), record)
        XCTAssertFalse(try store.remove(ifMatching: record))
        try store.replace(record)
        XCTAssertTrue(try store.remove(ifMatching: record))
    }

    func testSameRecordHasStableFingerprintAndDifferentMetadataCannotRemoveIt() throws {
        let security = FoundationTestSecurity()
        let store = try makeStore(security: security)
        let record = try FoundationFixture.record()
        try store.replace(record)
        let first = try XCTUnwrap(security.attributes.last?[kSecAttrGeneric as String] as? Data)
        try store.replace(record)
        XCTAssertEqual(security.attributes.last?[kSecAttrGeneric as String] as? Data, first)
        let next = NovaAuthTokenRecord(
            version: record.version,
            context: NovaAuthContext(origin: record.context.origin, generation: record.context.generation + 1),
            flow: record.flow, clientID: record.clientID, accessToken: record.accessToken,
            issuedAt: record.issuedAt, expiresAt: record.expiresAt, issuanceStart: record.issuanceStart,
            earlyRefreshSeconds: record.earlyRefreshSeconds
        )
        try store.replace(next)
        XCTAssertFalse(try store.remove(ifMatching: record))
        XCTAssertEqual(try store.load(), next)
    }

    func testUnavailableUpdateAndDuplicateAddFailWithoutBlindRetry() throws {
        let security = FoundationTestSecurity()
        let store = try makeStore(security: security)
        security.updateStatus = errSecInteractionNotAllowed
        XCTAssertThrowsError(try store.replace(FoundationFixture.record()))
        XCTAssertEqual(security.events.map(\.0), ["update"])
        security.events.removeAll()
        security.updateStatus = errSecItemNotFound
        security.addStatus = errSecDuplicateItem
        XCTAssertThrowsError(try store.replace(FoundationFixture.record()))
        XCTAssertEqual(security.events.map(\.0), ["update", "add"])
    }

    func testSensitiveRecordReflectionIsRedacted() throws {
        let record = try FoundationFixture.record()
        XCTAssertFalse(String(describing: record).contains(FoundationFixture.token))
        XCTAssertFalse(String(reflecting: record).contains(FoundationFixture.clientID))
        XCTAssertTrue(Mirror(reflecting: record).children.isEmpty)
    }

    private func makeStore(security: FoundationTestSecurity) throws -> NovaAuthKeychainTokenStore {
        NovaAuthKeychainTokenStore(
            configuration: try NovaAuthSharedStoreConfiguration(
                accessGroup: "group.test.novaauth",
                containerURL: FileManager.default.temporaryDirectory,
                hostAppNamespace: "io.nova.wallet"
            ),
            security: security
        )
    }
}

final class FoundationTestSecurity: NovaAuthSecurityProtocol {
    private(set) var records: [[String]: Data] = [:]
    private var fingerprints: [[String]: Data] = [:]
    var readStatus: OSStatus?
    var updateStatus: OSStatus?
    var addStatus: OSStatus?
    var beforeDelete: (() throws -> Void)?
    var afterCopy: (() throws -> Void)?
    var events: [(String, [String: Any])] = []
    var attributes: [[String: Any]] = []

    func copy(_ query: [String: Any]) -> (OSStatus, Data?) {
        events.append(("copy", query))
        guard let key = itemKey(query) else { return (errSecParam, nil) }
        let data = records[key]
        let callback = afterCopy
        afterCopy = nil
        do { try callback?() } catch { XCTFail("copy boundary mutation failed: \(error)") }
        return (readStatus ?? (data == nil ? errSecItemNotFound : errSecSuccess), data)
    }

    func add(_ query: [String: Any]) -> OSStatus {
        events.append(("add", query))
        attributes.append(query)
        if let addStatus { return addStatus }
        guard let key = itemKey(query), let data = query[kSecValueData as String] as? Data else { return errSecParam }
        guard records[key] == nil else { return errSecDuplicateItem }
        records[key] = data
        fingerprints[key] = query[kSecAttrGeneric as String] as? Data
        return errSecSuccess
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        events.append(("update", query))
        self.attributes.append(attributes)
        if let updateStatus { return updateStatus }
        guard let key = itemKey(query), let data = attributes[kSecValueData as String] as? Data else { return errSecParam }
        guard records[key] != nil else { return errSecItemNotFound }
        records[key] = data
        fingerprints[key] = attributes[kSecAttrGeneric as String] as? Data
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        events.append(("delete", query))
        let callback = beforeDelete
        beforeDelete = nil
        do { try callback?() } catch { XCTFail("delete boundary mutation failed: \(error)") }
        guard let key = itemKey(query) else { return errSecParam }
        if let expected = query[kSecAttrGeneric as String] as? Data, fingerprints[key] != expected {
            return errSecItemNotFound
        }
        fingerprints.removeValue(forKey: key)
        return records.removeValue(forKey: key) == nil ? errSecItemNotFound : errSecSuccess
    }

    func setData(_ data: Data, matching query: [String: Any]) {
        guard let key = itemKey(query) else { return XCTFail("Incomplete Keychain query") }
        records[key] = data
    }

    func clearFingerprint(matching query: [String: Any]) {
        guard let key = itemKey(query) else { return XCTFail("Incomplete Keychain query") }
        fingerprints.removeValue(forKey: key)
    }

    private func itemKey(_ query: [String: Any]) -> [String]? {
        let attributes = [kSecClass, kSecAttrService, kSecAttrAccount, kSecAttrAccessGroup]
        let key = attributes.compactMap { query[$0 as String] as? String }
        return key.count == attributes.count ? key : nil
    }
}

private final class DroppingSettings: SettingsManagerProtocol {
    func set(value _: Bool, for _: String) {}
    func set(value _: Int, for _: String) {}
    func set(value _: Double, for _: String) {}
    func set(value _: String, for _: String) {}
    func set(value _: Data, for _: String) {}
    func set(anyValue _: Any, for _: String) {}
    func bool(for _: String) -> Bool? { nil }
    func integer(for _: String) -> Int? { nil }
    func double(for _: String) -> Double? { nil }
    func string(for _: String) -> String? { nil }
    func data(for _: String) -> Data? { nil }
    func anyValue(for _: String) -> Any? { nil }
    func removeValue(for _: String) {}
    func removeAll() {}
}
