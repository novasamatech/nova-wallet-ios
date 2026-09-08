import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo
import NovaAppAttest

final class AnalyticsAttestationFixtureRecorderTests: XCTestCase {
    func testFixtureSerializesEveryFieldTheGatewayNeeds() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let json = String(data: try encoder.encode(try record()), encoding: .utf8)

        for field in ["attestationChallenge", "assertionChallenge", "clientId", "keyId", "attestationBase64", "bodyBase64", "assertionBase64"] {
            XCTAssertTrue(json?.contains(field) == true, "fixture is missing \(field)")
        }
    }

    private func record() throws -> AnalyticsAttestationFixture {
        let remote = MockBackendAttestationRemoteFactoryProtocol()
        stub(remote) { stub in
            when(stub.createChallengeWrapper()).then { _ in
                CompoundOperationWrapper(targetOperation: ClosureOperation<String> { UUID().uuidString })
            }
        }

        let appAttest = MockAppAttestServiceProtocol()
        stub(appAttest) { stub in
            when(stub.createKeyGenerationOperation()).then { _ in
                ClosureOperation<AppAttestKeyId> { "generated-key-id" }
            }
            when(stub.createAttestationWrapper(using: any(), clientData: any())).then { keyId, _ in
                CompoundOperationWrapper(targetOperation: ClosureOperation<AppAttestAttestation> {
                    AppAttestAttestation(keyId: keyId, attestation: Data("attestation-object".utf8))
                })
            }
            when(stub.createAssertionWrapper(keyId: any(), clientData: any())).then { _, _ in
                CompoundOperationWrapper(targetOperation: ClosureOperation<AppAttestAssertion> { Data("assertion".utf8) })
            }
        }

        let identity = MockBackendAttestationIdentityProtocol()
        stub(identity) { stub in
            when(stub.clientId()).thenReturn("cid")
        }

        let recorder = AnalyticsAttestationFixtureRecorder(appAttest: appAttest, remoteFactory: remote, identity: identity, operationQueue: OperationQueue())

        let wrapper = recorder.recordWrapper()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
