#if F_DEV

    import Foundation
    import Operation_iOS
    import NovaAppAttest

    /// Spec §7.6's deliverable: the sample the gateway's iOS verifier is tested against.
    /// An attestation and an assertion cannot be produced off-device, so this is the only way
    /// to obtain one, and it must be recorded on a physical device.
    struct AnalyticsAttestationFixture: Encodable {
        /// Both challenges are recorded because the two client-data digests are built from
        /// different ones: with only the assertion challenge the gateway cannot reconstruct
        /// the attestation's `clientDataHash`, so `attestationBase64` is unverifiable.
        let attestationChallenge: String
        let assertionChallenge: String
        let clientId: String
        let keyId: String
        let attestationBase64: String
        let bodyBase64: String
        let assertionBase64: String
    }

    /// Drives the attestation cycle directly rather than through `BackendAttestationProvider`,
    /// which by design exposes only finished headers. The fixture needs every intermediate
    /// value, so the cycle is run here with capture points.
    final class AnalyticsAttestationFixtureRecorder {
        /// A fixed body so a re-recording is comparable with the previous one.
        static let sampleBody = Data(#"{"v":1,"fixture":true}"#.utf8)

        private let appAttest: AppAttestServiceProtocol
        private let remoteFactory: BackendAttestationRemoteFactoryProtocol
        private let identity: BackendAttestationIdentityProtocol
        private let operationQueue: OperationQueue

        init(
            appAttest: AppAttestServiceProtocol,
            remoteFactory: BackendAttestationRemoteFactoryProtocol,
            identity: BackendAttestationIdentityProtocol,
            operationQueue: OperationQueue
        ) {
            self.appAttest = appAttest
            self.remoteFactory = remoteFactory
            self.identity = identity
            self.operationQueue = operationQueue
        }

        func recordWrapper() -> CompoundOperationWrapper<AnalyticsAttestationFixture> {
            guard let clientId = identity.clientId() else {
                return .createWithError(BackendAttestationError.unsupported)
            }

            let body = Self.sampleBody

            let attestChallengeWrapper = remoteFactory.createChallengeWrapper()

            let attestationWrapper = appAttest.createAttestationWrapper(using: nil) { keyId in
                let challenge = try attestChallengeWrapper.targetOperation.extractNoCancellableResultData()

                return AttestationClientData.attestationClientData(
                    challenge: challenge,
                    clientId: clientId,
                    keyId: keyId
                )
            }

            attestationWrapper.addDependency(wrapper: attestChallengeWrapper)

            let assertChallengeWrapper = remoteFactory.createChallengeWrapper()
            assertChallengeWrapper.addDependency(wrapper: attestationWrapper)

            let assertionWrapper = OperationCombiningService<AppAttestAssertion>.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) { [appAttest] in
                let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()

                return appAttest.createAssertionWrapper(keyId: attestation.keyId) {
                    let challenge = try assertChallengeWrapper.targetOperation
                        .extractNoCancellableResultData()

                    return AttestationClientData.assertionClientData(
                        challenge: challenge,
                        clientId: clientId,
                        body: body
                    )
                }
            }

            assertionWrapper.addDependency(wrapper: assertChallengeWrapper)

            let mapOperation = ClosureOperation<AnalyticsAttestationFixture> {
                let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()
                let assertion = try assertionWrapper.targetOperation.extractNoCancellableResultData()
                let attestChallenge = try attestChallengeWrapper.targetOperation
                    .extractNoCancellableResultData()
                let assertChallenge = try assertChallengeWrapper.targetOperation
                    .extractNoCancellableResultData()

                return AnalyticsAttestationFixture(
                    attestationChallenge: attestChallenge,
                    // The challenge the gateway must replay to reproduce the signature
                    // over `bodyBase64`.
                    assertionChallenge: assertChallenge,
                    clientId: clientId,
                    keyId: attestation.keyId,
                    attestationBase64: attestation.attestation.base64EncodedString(),
                    bodyBase64: body.base64EncodedString(),
                    assertionBase64: assertion.base64EncodedString()
                )
            }

            mapOperation.addDependency(assertionWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: attestChallengeWrapper.allOperations
                    + attestationWrapper.allOperations
                    + assertChallengeWrapper.allOperations
                    + assertionWrapper.allOperations
            )
        }
    }

#endif
