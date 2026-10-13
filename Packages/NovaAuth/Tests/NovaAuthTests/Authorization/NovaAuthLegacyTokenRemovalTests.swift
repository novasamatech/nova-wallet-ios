import XCTest
import Security
@testable import NovaAuth

final class NovaAuthLegacyTokenRemovalTests: LifecycleTestCase {
    func testIssuerRejectionRemovesUnchangedUntaggedRecord() throws {
        let fixture = try LegacyTokenFixture()
        try fixture.owner.reject(record: fixture.record, repeated: false, requestID: nil)
        XCTAssertEqual(fixture.unconditionalDeletes, 1)
        XCTAssertNil(try fixture.store.load())
    }

    func testIssuerExpiryRemovesUnchangedUntaggedRecord() throws {
        let fixture = try LegacyTokenFixture()
        fixture.harness.clock.advance(600)
        let usable = try fixture.owner.gate.novaAuthLocked {
            try fixture.owner.usableToken(context: fixture.record.context, now: fixture.harness.clock.now())
        }
        XCTAssertNil(usable)
        XCTAssertEqual(fixture.unconditionalDeletes, 1)
        XCTAssertNil(try fixture.store.load())
    }

    func testIssuerRejectionPreservesReplacementInstalledBeforeConditionalDelete() throws {
        let fixture = try LegacyTokenFixture()
        let replacement = fixture.harness.record(context: fixture.record.context, bearer: "newer-bearer")
        fixture.security.beforeDelete = { try fixture.store.replace(replacement) }
        try fixture.owner.reject(record: fixture.record, repeated: false, requestID: nil)
        XCTAssertEqual(fixture.unconditionalDeletes, 0)
        XCTAssertEqual(try fixture.store.load(), replacement)
    }

    func testIssuerExpiryPreservesReplacementInstalledBeforeConditionalDelete() throws {
        let fixture = try LegacyTokenFixture()
        fixture.harness.clock.advance(600)
        let replacement = fixture.harness.record(context: fixture.record.context, bearer: "newer-bearer", start: 700)
        fixture.security.beforeDelete = { try fixture.store.replace(replacement) }
        let usable = try fixture.owner.gate.novaAuthLocked {
            try fixture.owner.usableToken(context: fixture.record.context, now: fixture.harness.clock.now())
        }
        XCTAssertNil(usable)
        XCTAssertEqual(fixture.unconditionalDeletes, 0)
        XCTAssertEqual(try fixture.store.load(), replacement)
    }

    func testIssuerDoesNotBlindlyRemoveLegacyRecordWhenFollowupLoadFails() throws {
        let fixture = try LegacyTokenFixture()
        fixture.security.readStatus = errSecInteractionNotAllowed
        XCTAssertThrowsError(try fixture.owner.reject(record: fixture.record, repeated: false, requestID: nil)) {
            XCTAssertEqual($0 as? NovaAuthError, .storageUnavailable)
        }
        XCTAssertEqual(fixture.unconditionalDeletes, 0)
        fixture.security.readStatus = nil
        XCTAssertEqual(try fixture.store.load(), fixture.record)
    }
}

private final class LegacyTokenFixture {
    let harness: LifecycleHarness
    let security: FoundationTestSecurity
    let store: NovaAuthKeychainTokenStore
    let record: NovaAuthTokenRecord
    let owner: NovaAuth

    var unconditionalDeletes: Int {
        security.events.filter { $0.0 == "delete" && $0.1[kSecAttrGeneric as String] == nil }.count
    }

    init() throws {
        let harness = try LifecycleHarness()
        let security = FoundationTestSecurity()
        let (_, context) = try harness.registered()
        let record = harness.record(context: context)
        let store = NovaAuthKeychainTokenStore(
            configuration: try NovaAuthSharedStoreConfiguration(
                accessGroup: "group.test.novaauth", hostAppNamespace: "io.nova.wallet"
            ),
            security: security
        )
        try store.replace(record)
        security.clearFingerprint(matching: try XCTUnwrap(security.events.last?.1))
        let owner = NovaAuth(dependencies: NovaAuthDependencies(
            appAttest: harness.apple, identityStore: harness.identity, tokenStore: store,
            clock: harness.clock, random: harness.random, bootstrap: harness.bootstrap, http: harness.http,
            ownerQueue: harness.ownerQueue, bootstrapQueue: harness.bootstrapQueue,
            requestQueue: harness.requestQueue, appIdentity: harness.appIdentity, logger: nil
        ))
        _ = try owner.activate(origin: harness.origin)
        security.events.removeAll()
        self.harness = harness
        self.security = security
        self.store = store
        self.record = record
        self.owner = owner
    }
}
