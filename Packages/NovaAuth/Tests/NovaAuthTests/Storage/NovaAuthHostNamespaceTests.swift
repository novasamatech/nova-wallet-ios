import XCTest
import Keystore_iOS
@testable import NovaAuth

final class NovaAuthHostNamespaceTests: XCTestCase {
    private let releaseNamespace = "io.novafoundation.novawallet"
    private let stagingNamespace = "io.novafoundation.novawallet.staging"

    func testHostNamespaceIsRequiredAndValidatedWithoutNormalization() throws {
        for namespace in [releaseNamespace, stagingNamespace, "io.novafoundation.novawallet.dev"] {
            XCTAssertEqual(try configuration(namespace).hostAppNamespace, namespace)
        }
        let invalid = [
            "", "novawallet", ".io.nova", "io.nova.", "io..nova", "io.nova/extension",
            "io.nova wallet", "io.nóva", "io.nova\n", "$(NOVA_AUTH_HOST_APP_NAMESPACE)",
            "io." + String(repeating: "a", count: 253)
        ]
        for namespace in invalid {
            XCTAssertThrowsError(try configuration(namespace)) {
                XCTAssertEqual($0 as? NovaAuthError, .invalidConfiguration)
            }
        }
    }

    func testStoresInSameGroupIsolateLoadReplaceConditionalRemoveAndCleanup() throws {
        let security = FoundationTestSecurity()
        let release = try store(releaseNamespace, security: security)
        let staging = try store(stagingNamespace, security: security)
        let original = try FoundationFixture.record()
        let replacement = try FoundationFixture.record(token: "replacement")

        try release.replace(original)
        XCTAssertNil(try staging.load())
        XCTAssertFalse(try staging.remove(ifMatching: original))
        try staging.removeAll()
        XCTAssertTrue(try release.load() == original)

        // Even identical records must be independently removable in separate host namespaces.
        try staging.replace(original)
        XCTAssertEqual(security.records.count, 2)
        XCTAssertTrue(try staging.remove(ifMatching: original))
        XCTAssertTrue(try release.load() == original)
        try staging.replace(replacement)
        XCTAssertTrue(try staging.load() == replacement)
        XCTAssertTrue(try release.load() == original)
        XCTAssertFalse(try release.remove(ifMatching: replacement))

        _ = try staging.load()
        security.setData(Data("malformed".utf8), matching: try XCTUnwrap(security.events.last?.1))
        XCTAssertNil(try staging.load())
        XCTAssertTrue(try release.load() == original)
        try staging.replace(replacement)
        try release.removeAll()
        XCTAssertNil(try release.load())
        XCTAssertTrue(try staging.load() == replacement)
    }

    func testMainAndOwnReaderShareBearerWhileSiblingResetCannotRemoveIt() throws {
        let security = FoundationTestSecurity()
        let releaseStore = try store(releaseNamespace, security: security)
        let stagingStore = try store(stagingNamespace, security: security)
        let releaseRecord = try FoundationFixture.record()
        let stagingRecord = try record(clientID: "6f2c1e4a-0000-4000-8000-000000000002")
        try releaseStore.replace(releaseRecord)
        try stagingStore.replace(stagingRecord)
        let release = try main(store: releaseStore, namespace: releaseNamespace, record: releaseRecord)
        let staging = try main(store: stagingStore, namespace: stagingNamespace, record: stagingRecord)
        let releaseReader = try reader(store: store(releaseNamespace, security: security))
        let stagingReader = try reader(store: store(stagingNamespace, security: security))

        try executeFoundation(release.createAdmissionWrapper(in: releaseRecord.context, intent: .background))
        try executeFoundation(staging.createAdmissionWrapper(in: stagingRecord.context, intent: .background))
        XCTAssertEqual(try executeFoundation(releaseReader.createContextWrapper()), releaseRecord.context)
        XCTAssertEqual(try executeFoundation(stagingReader.createContextWrapper()), stagingRecord.context)

        try release.reset()
        XCTAssertNil(try releaseStore.load())
        XCTAssertTrue(try stagingStore.load() == stagingRecord)
        XCTAssertThrowsError(try executeFoundation(releaseReader.createContextWrapper())) {
            XCTAssertEqual($0 as? NovaAuthError, .credentialUnavailable)
        }
        try executeFoundation(staging.createAdmissionWrapper(in: stagingRecord.context, intent: .background))
        try executeFoundation(stagingReader.createAdmissionWrapper(in: stagingRecord.context, intent: .background))
    }

    func testReaderWithWrongNamespaceCannotSendSiblingBearer() throws {
        let security = FoundationTestSecurity()
        let releaseStore = try store(releaseNamespace, security: security)
        let record = try FoundationFixture.record()
        try releaseStore.replace(record)
        let http = FoundationTestHTTP()
        http.response = try FoundationFixture.response("{}")
        let ownReader = try reader(store: store(releaseNamespace, security: security), http: http)
        let wrongReader = try reader(store: store(stagingNamespace, security: security), http: http)
        let request = try NovaAuthRequest(
            context: record.context, method: .get, path: "/v1/bittensor/profile-3/subnets",
            queryItems: [], body: nil, contentType: nil, intent: .background
        )

        XCTAssertThrowsError(try executeFoundation(wrongReader.createResponseWrapper(for: request, beforeSend: {}))) {
            XCTAssertEqual($0 as? NovaAuthError, .credentialUnavailable)
        }
        XCTAssertTrue(http.requests.isEmpty)
        _ = try executeFoundation(ownReader.createResponseWrapper(for: request, beforeSend: {}))
        XCTAssertEqual(http.requests.count, 1)
        XCTAssertTrue(http.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer \(record.accessToken)")
        XCTAssertTrue(try releaseStore.load() == record)
    }
}

private extension NovaAuthHostNamespaceTests {
    func configuration(_ namespace: String) throws -> NovaAuthSharedStoreConfiguration {
        try NovaAuthSharedStoreConfiguration(
            accessGroup: "group.novafoundation.novawallet",
            hostAppNamespace: namespace
        )
    }

    func store(
        _ namespace: String,
        security: FoundationTestSecurity
    ) throws -> NovaAuthKeychainTokenStore {
        NovaAuthKeychainTokenStore(configuration: try configuration(namespace), security: security)
    }

    func record(clientID: String) throws -> NovaAuthTokenRecord {
        NovaAuthTokenRecord(
            version: 1, context: try FoundationFixture.context(), flow: "bittensor-read",
            clientID: clientID, accessToken: "staging-bearer", issuedAt: 1000, expiresAt: 1300,
            issuanceStart: NovaAuthTime(bootID: "boot-a", continuousSeconds: 50), earlyRefreshSeconds: 70
        )
    }

    func main(store: NovaAuthKeychainTokenStore, namespace: String, record: NovaAuthTokenRecord) throws -> NovaAuth {
        let identityStore = NovaAuthSettingsIdentityStore(settingsManager: InMemorySettingsManager())
        try identityStore.save(NovaAuthInstallationState(
            version: 1, context: record.context, requiresUserAction: false,
            identity: NovaAuthInstallationIdentity(
                clientID: record.clientID, keyID: FoundationFixture.keyID, registration: .registered
            )
        ))
        let ownerQueue = OperationQueue()
        ownerQueue.maxConcurrentOperationCount = 1
        let auth = NovaAuth(dependencies: NovaAuthDependencies(
            appAttest: LifecycleApple(), identityStore: identityStore, tokenStore: store,
            clock: FoundationTestClock(), random: LifecycleRandom(), bootstrap: LifecycleBootstrap(),
            http: FoundationTestHTTP(), ownerQueue: ownerQueue, bootstrapQueue: OperationQueue(),
            requestQueue: OperationQueue(),
            appIdentity: try NovaAuthAppIdentity(appID: "PREFIX.\(namespace)", environment: .production), logger: nil
        ))
        _ = try auth.activate(origin: record.context.origin)
        return auth
    }

    func reader(store: NovaAuthKeychainTokenStore, http: FoundationTestHTTP = FoundationTestHTTP()) throws -> NovaAuthReader {
        NovaAuthReader(dependencies: NovaAuthReaderDependencies(
            origin: try FoundationFixture.origin(), tokenStore: store, clock: FoundationTestClock(),
            http: http, requestQueue: OperationQueue()
        ))
    }
}
