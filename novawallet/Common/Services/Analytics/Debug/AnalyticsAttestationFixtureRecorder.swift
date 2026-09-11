#if F_DEV

    import Foundation
    import Operation_iOS
    import NovaAppAttest

    /// The sample the gateway's iOS verifier is tested against.
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

            let keyGenerationOperation = appAttest.createKeyGenerationOperation()

            let attestChallengeWrapper = remoteFactory.createChallengeWrapper()

            let attestationWrapper = createAttestationWrapper(
                clientId: clientId,
                keyGenerationOperation: keyGenerationOperation,
                challengeWrapper: attestChallengeWrapper
            )

            attestationWrapper.addDependency(operations: [keyGenerationOperation])
            attestationWrapper.addDependency(wrapper: attestChallengeWrapper)

            let assertChallengeWrapper = remoteFactory.createChallengeWrapper()
            assertChallengeWrapper.addDependency(wrapper: attestationWrapper)

            let assertionWrapper = createAssertionWrapper(
                clientId: clientId,
                attestationWrapper: attestationWrapper,
                challengeWrapper: assertChallengeWrapper
            )

            assertionWrapper.addDependency(wrapper: assertChallengeWrapper)

            let mapOperation = createFixtureOperation(
                clientId: clientId,
                attestChallengeWrapper: attestChallengeWrapper,
                assertChallengeWrapper: assertChallengeWrapper,
                attestationWrapper: attestationWrapper,
                assertionWrapper: assertionWrapper
            )

            mapOperation.addDependency(assertionWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [keyGenerationOperation]
                    + attestChallengeWrapper.allOperations
                    + attestationWrapper.allOperations
                    + assertChallengeWrapper.allOperations
                    + assertionWrapper.allOperations
            )
        }
    }

    // MARK: - Private

    private extension AnalyticsAttestationFixtureRecorder {
        func createAttestationWrapper(
            clientId: String,
            keyGenerationOperation: BaseOperation<AppAttestKeyId>,
            challengeWrapper: CompoundOperationWrapper<String>
        ) -> CompoundOperationWrapper<AppAttestAttestation> {
            OperationCombiningService<AppAttestAttestation>.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) { [appAttest] in
                let keyId = try keyGenerationOperation.extractNoCancellableResultData()
                let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

                return appAttest.createAttestationWrapper(using: keyId) { attestingKeyId in
                    AttestationClientData.attestationClientData(
                        challenge: challenge,
                        clientId: clientId,
                        keyId: attestingKeyId
                    )
                }
            }
        }

        func createAssertionWrapper(
            clientId: String,
            attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>,
            challengeWrapper: CompoundOperationWrapper<String>
        ) -> CompoundOperationWrapper<AppAttestAssertion> {
            let body = Self.sampleBody

            return OperationCombiningService<AppAttestAssertion>.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) { [appAttest] in
                let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()

                return appAttest.createAssertionWrapper(keyId: attestation.keyId) {
                    let challenge = try challengeWrapper.targetOperation
                        .extractNoCancellableResultData()

                    return AttestationClientData.assertionClientData(
                        challenge: challenge,
                        clientId: clientId,
                        body: body
                    )
                }
            }
        }

        func createFixtureOperation(
            clientId: String,
            attestChallengeWrapper: CompoundOperationWrapper<String>,
            assertChallengeWrapper: CompoundOperationWrapper<String>,
            attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>,
            assertionWrapper: CompoundOperationWrapper<AppAttestAssertion>
        ) -> BaseOperation<AnalyticsAttestationFixture> {
            let body = Self.sampleBody

            return ClosureOperation<AnalyticsAttestationFixture> {
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
        }
    }

#endif
