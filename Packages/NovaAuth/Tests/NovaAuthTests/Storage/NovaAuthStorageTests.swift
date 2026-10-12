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

    func testKeychainEveryQueryIsScopedAndAllAccessIsLocked() throws {
        let lock = FoundationTestFileLock()
        let security = FoundationTestSecurity(lock: lock)
        let store = try makeStore(security: security, lock: lock)
        let record = try FoundationFixture.record()
        XCTAssertNil(try store.load())
        try store.replace(record)
        XCTAssertTrue(try store.load() == record)
        try store.replace(FoundationFixture.record(token: "replacement"))
        XCTAssertFalse(try store.remove(ifMatching: record))
        try store.removeAll()
        XCTAssertEqual(security.events.filter { $0.0 == "add" }.count, 1)
        XCTAssertEqual(security.events.filter { $0.0 == "update" }.count, 2)
        XCTAssertEqual(security.events.filter { $0.0 == "delete" }.count, 1)
        for (_, query) in security.events {
            XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String)
            XCTAssertEqual(query[kSecAttrService as String] as? String, "io.novawallet.novaauth.profile3.io.nova.wallet")
            XCTAssertEqual(query[kSecAttrAccount as String] as? String, "current")
            XCTAssertEqual(query[kSecAttrAccessGroup as String] as? String, "group.test.novaauth")
            XCTAssertNil(query[kSecAttrSynchronizable as String])
        }
        for attributes in security.attributes {
            XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        }
        XCTAssertFalse(security.sawUnlockedCall)
        XCTAssertEqual(lock.depth, 0)
    }

    func testOldExtensionRejectionCannotRemoveMainReplacement() throws {
        let lock = FoundationTestFileLock()
        let security = FoundationTestSecurity(lock: lock)
        let main = try makeStore(security: security, lock: lock)
        let reader = try makeStore(security: security, lock: lock)
        let old = try FoundationFixture.record()
        let new = try FoundationFixture.record(token: "new-synthetic-token")
        try main.replace(old)
        let sent = try XCTUnwrap(reader.load())
        try main.replace(new)
        XCTAssertFalse(try reader.remove(ifMatching: sent))
        XCTAssertTrue(try main.load() == new)
        XCTAssertTrue(try reader.remove(ifMatching: new))
        XCTAssertNil(try main.load())
    }

    func testCorruptRecordCleanupUsesLockButDeniedReadNeverDeletes() throws {
        let lock = FoundationTestFileLock()
        let security = FoundationTestSecurity(lock: lock)
        let store = try makeStore(security: security, lock: lock)
        try store.replace(FoundationFixture.record())
        security.setData(Data("malformed".utf8), matching: try XCTUnwrap(security.events.last?.1))
        XCTAssertNil(try store.load())
        XCTAssertEqual(security.events.last?.0, "delete")
        XCTAssertFalse(security.sawUnlockedCall)
        security.events.removeAll()
        security.readStatus = errSecInteractionNotAllowed
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(security.events.map(\.0), ["copy"])
        security.readStatus = nil
        security.updateStatus = errSecInteractionNotAllowed
        XCTAssertThrowsError(try store.replace(FoundationFixture.record()))
        XCTAssertTrue(security.records.isEmpty)
    }

    func testLockFailureNeverTouchesKeychainAndAlwaysUnlocksAfterThrow() throws {
        let lock = FoundationTestFileLock()
        let security = FoundationTestSecurity(lock: lock)
        let store = try makeStore(security: security, lock: lock)
        lock.fail = true
        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.replace(FoundationFixture.record()))
        XCTAssertThrowsError(try store.removeAll())
        XCTAssertTrue(security.events.isEmpty)
        lock.fail = false
        security.readStatus = errSecMissingEntitlement
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(lock.depth, 0)
    }

    func testIndependentFileHandlesContendWithBoundedFailureAndRelease() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = NovaAuthFileLock(containerURL: directory)
        let second = NovaAuthFileLock(containerURL: directory, timeout: 0.01)
        try first.withLock {
            XCTAssertThrowsError(try second.withLock { XCTFail("must not enter contended lock") })
        }
        XCTAssertNoThrow(try second.withLock {})
        XCTAssertThrowsError(try first.withLock { throw NovaAuthError.invalidResponse })
        XCTAssertNoThrow(try second.withLock {})
        let path = directory.appendingPathComponent("NovaAuth/profile3.lock").path
        let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600)
    }

    func testSensitiveRecordReflectionIsRedacted() throws {
        let record = try FoundationFixture.record()
        XCTAssertFalse(String(describing: record).contains(FoundationFixture.token))
        XCTAssertFalse(String(reflecting: record).contains(FoundationFixture.clientID))
        XCTAssertTrue(Mirror(reflecting: record).children.isEmpty)
    }

    private func makeStore(security: FoundationTestSecurity, lock: FoundationTestFileLock) throws -> NovaAuthKeychainTokenStore {
        NovaAuthKeychainTokenStore(
            configuration: try NovaAuthSharedStoreConfiguration(
                accessGroup: "group.test.novaauth",
                containerURL: FileManager.default.temporaryDirectory,
                hostAppNamespace: "io.nova.wallet"
            ),
            security: security,
            fileLock: lock
        )
    }
}

final class FoundationTestFileLock: NovaAuthFileLockProtocol {
    var depth = 0
    var fail = false
    func withLock<T>(_ body: () throws -> T) throws -> T {
        if fail { throw NovaAuthError.storageUnavailable }
        depth += 1
        defer { depth -= 1 }
        return try body()
    }
}

final class FoundationTestSecurity: NovaAuthSecurityProtocol {
    let lock: FoundationTestFileLock
    private(set) var records: [[String]: Data] = [:]
    var readStatus: OSStatus?
    var updateStatus: OSStatus?
    var sawUnlockedCall = false
    var events: [(String, [String: Any])] = []
    var attributes: [[String: Any]] = []
    init(lock: FoundationTestFileLock) { self.lock = lock }
    func record(_ action: String, _ query: [String: Any]) {
        sawUnlockedCall = sawUnlockedCall || lock.depth != 1
        events.append((action, query))
    }

    func copy(_ query: [String: Any]) -> (OSStatus, Data?) {
        record("copy", query)
        guard let key = itemKey(query) else { return (errSecParam, nil) }
        let data = records[key]
        return (readStatus ?? (data == nil ? errSecItemNotFound : errSecSuccess), data)
    }

    func add(_ query: [String: Any]) -> OSStatus {
        record("add", query)
        attributes.append(query)
        guard let key = itemKey(query), let data = query[kSecValueData as String] as? Data else { return errSecParam }
        guard records[key] == nil else { return errSecDuplicateItem }
        records[key] = data
        return errSecSuccess
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        record("update", query)
        self.attributes.append(attributes)
        if let updateStatus { return updateStatus }
        guard let key = itemKey(query), let data = attributes[kSecValueData as String] as? Data else { return errSecParam }
        guard records[key] != nil else { return errSecItemNotFound }
        records[key] = data
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        record("delete", query)
        guard let key = itemKey(query) else { return errSecParam }
        return records.removeValue(forKey: key) == nil ? errSecItemNotFound : errSecSuccess
    }

    func setData(_ data: Data, matching query: [String: Any]) {
        guard let key = itemKey(query) else { return XCTFail("Incomplete Keychain query") }
        records[key] = data
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
