import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

// No `#if F_DEV` guard here: the test target does not define F_DEV, so guarding this file
// would delete the whole suite and `-only-testing:` would silently report success. The app
// module is built with -DF_DEV in Debug, so these symbols exist and @testable can see them.
final class AnalyticsAttestationFixtureRecorderTests: XCTestCase {
    private struct Recorded {
        let fixture: AnalyticsAttestationFixture
        let attestationClientData: Data
        let assertionClientData: Data
    }

    /// Runs the recorder's real chain against mocked Apple and gateway seams. Challenges are
    /// numbered so the two round trips are distinguishable, which is the whole point: the
    /// two client-data digests are built from different challenges.
    private func record() throws -> Recorded {
        let challengeCounter = Counter()
        let clientDataStore = ClientDataStore()

        let remote = MockBackendAttestationRemoteFactoryProtocol()
        stub(remote) { stub in
            when(stub.createChallengeWrapper()).then { _ in
                CompoundOperationWrapper(targetOperation: ClosureOperation<String> {
                    "challenge-\(challengeCounter.next())"
                })
            }
        }

        let appAttest = MockAppAttestServiceProtocol()
        stub(appAttest) { stub in
            when(stub.isSupported.get).thenReturn(true)

            when(stub.createAttestationWrapper(using: any(), clientData: any())).then { _, clientData in
                CompoundOperationWrapper(targetOperation: ClosureOperation<AppAttestAttestation> {
                    clientDataStore.attestation = try clientData("key-id")

                    return AppAttestAttestation(
                        keyId: "key-id",
                        attestation: Data("attestation-object".utf8)
                    )
                })
            }

            when(stub.createAssertionWrapper(keyId: any(), clientData: any())).then { _, clientData in
                CompoundOperationWrapper(targetOperation: ClosureOperation<AppAttestAssertion> {
                    clientDataStore.assertion = try clientData()

                    return Data("assertion".utf8)
                })
            }
        }

        let identity = MockBackendAttestationIdentityProtocol()
        stub(identity) { stub in
            when(stub.clientId()).thenReturn("cid")
            when(stub.consentEpoch.get).thenReturn(0)
        }

        let recorder = AnalyticsAttestationFixtureRecorder(
            appAttest: appAttest,
            remoteFactory: remote,
            identity: identity,
            operationQueue: OperationQueue()
        )

        let wrapper = recorder.recordWrapper()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return Recorded(
            fixture: try wrapper.targetOperation.extractNoCancellableResultData(),
            attestationClientData: try XCTUnwrap(clientDataStore.attestation),
            assertionClientData: try XCTUnwrap(clientDataStore.assertion)
        )
    }

    func testFixtureSerializesEveryFieldTheGatewayNeeds() throws {
        let json = String(
            data: try AnalyticsCoding.encoder.encode(try record().fixture),
            encoding: .utf8
        )

        for field in [
            "attestationChallenge",
            "assertionChallenge",
            "clientId",
            "keyId",
            "attestationBase64",
            "bodyBase64",
            "assertionBase64"
        ] {
            XCTAssertTrue(json?.contains(field) == true, "fixture is missing \(field)")
        }
    }

    /// A fixture carrying only the assertion challenge cannot be verified: the gateway has
    /// no way to rebuild the attestation's `clientDataHash`, so `attestationBase64` is dead
    /// weight in the file.
    func testBothChallengesAreRecordedAndTheyDiffer() throws {
        let fixture = try record().fixture

        XCTAssertFalse(fixture.attestationChallenge.isEmpty)
        XCTAssertFalse(fixture.assertionChallenge.isEmpty)
        XCTAssertNotEqual(fixture.attestationChallenge, fixture.assertionChallenge)
    }

    func testEachRecordedChallengeIsTheOneItsOwnDigestWasBuiltFrom() throws {
        let recorded = try record()

        XCTAssertEqual(
            recorded.attestationClientData,
            AttestationClientData.attestationClientData(
                challenge: recorded.fixture.attestationChallenge,
                clientId: recorded.fixture.clientId,
                keyId: recorded.fixture.keyId
            )
        )

        XCTAssertEqual(
            recorded.assertionClientData,
            AttestationClientData.assertionClientData(
                challenge: recorded.fixture.assertionChallenge,
                clientId: recorded.fixture.clientId,
                body: AnalyticsAttestationFixtureRecorder.sampleBody
            )
        )
    }

    func testTheReportedBodyIsTheBodyThatWasSigned() throws {
        let recorded = try record()

        XCTAssertEqual(
            Data(base64Encoded: recorded.fixture.bodyBase64),
            AnalyticsAttestationFixtureRecorder.sampleBody
        )
        XCTAssertTrue(
            String(data: recorded.assertionClientData, encoding: .utf8)?
                .hasSuffix(
                    AttestationClientData.bodyDigestHex(
                        AnalyticsAttestationFixtureRecorder.sampleBody
                    )
                ) == true
        )
    }
}

private final class Counter {
    private let mutex = NSLock()
    private var value = 0

    func next() -> Int {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        value += 1

        return value
    }
}

private final class ClientDataStore {
    private let mutex = NSLock()
    private var attestationData: Data?
    private var assertionData: Data?

    var attestation: Data? {
        get { withLock { attestationData } }
        set { withLock { attestationData = newValue } }
    }

    var assertion: Data? {
        get { withLock { assertionData } }
        set { withLock { assertionData = newValue } }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body()
    }
}
