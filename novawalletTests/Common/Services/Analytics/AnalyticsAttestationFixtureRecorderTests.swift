import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo
import NovaAppAttest

final class AnalyticsAttestationFixtureRecorderTests: XCTestCase {
    private let registerTarget = try! AttestationRequestTarget(
        url: URL(string: "https://gateway.example/v1/attestation/register")!,
        method: "post",
        contentType: "application/json"
    )

    private let requestTarget = try! AttestationRequestTarget(
        url: URL(string: "https://gateway.example/v1/analytics/events")!,
        method: "post",
        contentType: "application/json"
    )

    /// The gateway rebuilds both profile-2 preimages from this file alone, so every framed field has
    /// to survive encoding — the two challenges, the binding, and both signed targets.
    func testFixtureSerializesEveryFieldTheGatewayNeeds() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let json = String(data: try encoder.encode(try record()), encoding: .utf8)

        let fields = [
            "profile", "clientId", "appId", "appAttestEnvironment", "keyId",
            "attestationChallenge", "attestationTarget", "attestationBase64",
            "assertionChallenge", "assertionTarget", "bodyBase64", "assertionBase64",
            "authority", "contentType", "method", "path", "port", "scheme"
        ]

        for field in fields {
            XCTAssertTrue(json?.contains(field) == true, "fixture is missing \(field)")
        }
    }

    private func record() throws -> AnalyticsAttestationFixture {
        let remote = MockBackendAttestationRemoteFactoryProtocol()
        stub(remote) { stub in
            when(stub.registerTarget()).thenReturn(registerTarget)
            when(stub.createChallengeWrapper(clientId: any(), purpose: any())).then { _, _ in
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

        let recorder = AnalyticsAttestationFixtureRecorder(
            appAttest: appAttest,
            remoteFactory: remote,
            identity: identity,
            appIdentity: AppAttestAppIdentity(
                appId: "ABCDEFGHIJ.com.example.nova",
                environment: "production"
            ),
            requestTarget: requestTarget,
            operationQueue: OperationQueue()
        )

        let wrapper = recorder.recordWrapper()
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
