#if F_DEV

    import Foundation
    import Operation_iOS
    import NovaAppAttest

    /// The sample the gateway's iOS verifier is tested against.
    /// An attestation and an assertion cannot be produced off-device, so this is the only way
    /// to obtain one, and it must be recorded on a physical device.
    struct AnalyticsAttestationFixture: Encodable {
        /// Everything profile 2 frames into the two preimages, so the gateway can rebuild both
        /// digests from this file alone. The challenges differ because registration and a protected
        /// request each consume their own.
        struct Target: Encodable {
            let method: String
            let scheme: String
            let authority: String
            let port: String
            let path: String
            let contentType: String

            init(_ target: AttestationRequestTarget) {
                method = target.method
                scheme = target.scheme
                authority = target.authority
                port = target.port
                path = target.path
                contentType = target.contentType
            }
        }

        let profile: Int
        let clientId: String
        let appId: String
        let appAttestEnvironment: String
        let keyId: String
        let attestationChallenge: String
        let attestationTarget: Target
        let attestationBase64: String
        let assertionChallenge: String
        let assertionTarget: Target
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
        private let appIdentity: AppAttestAppIdentity
        private let requestTarget: AttestationRequestTarget
        private let operationQueue: OperationQueue

        init(
            appAttest: AppAttestServiceProtocol,
            remoteFactory: BackendAttestationRemoteFactoryProtocol,
            identity: BackendAttestationIdentityProtocol,
            appIdentity: AppAttestAppIdentity,
            requestTarget: AttestationRequestTarget,
            operationQueue: OperationQueue
        ) {
            self.appAttest = appAttest
            self.remoteFactory = remoteFactory
            self.identity = identity
            self.appIdentity = appIdentity
            self.requestTarget = requestTarget
            self.operationQueue = operationQueue
        }

        func recordWrapper() -> CompoundOperationWrapper<AnalyticsAttestationFixture> {
            guard let clientId = identity.clientId() else {
                return .createWithError(BackendAttestationError.unsupported)
            }

            let registerTarget: AttestationRequestTarget

            do {
                registerTarget = try remoteFactory.registerTarget()
            } catch {
                return .createWithError(error)
            }

            let keyGenerationOperation = appAttest.createKeyGenerationOperation()

            let attestChallengeWrapper = remoteFactory.createChallengeWrapper(
                clientId: clientId,
                purpose: .register
            )

            let attestationWrapper = createAttestationWrapper(
                clientId: clientId,
                target: registerTarget,
                keyGenerationOperation: keyGenerationOperation,
                challengeWrapper: attestChallengeWrapper
            )

            attestationWrapper.addDependency(operations: [keyGenerationOperation])
            attestationWrapper.addDependency(wrapper: attestChallengeWrapper)

            let assertChallengeWrapper = remoteFactory.createChallengeWrapper(
                clientId: clientId,
                purpose: .request
            )
            assertChallengeWrapper.addDependency(wrapper: attestationWrapper)

            let assertionWrapper = createAssertionWrapper(
                clientId: clientId,
                attestationWrapper: attestationWrapper,
                challengeWrapper: assertChallengeWrapper
            )

            assertionWrapper.addDependency(wrapper: assertChallengeWrapper)

            let mapOperation = createFixtureOperation(
                clientId: clientId,
                registerTarget: registerTarget,
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
            target: AttestationRequestTarget,
            keyGenerationOperation: BaseOperation<AppAttestKeyId>,
            challengeWrapper: CompoundOperationWrapper<String>
        ) -> CompoundOperationWrapper<AppAttestAttestation> {
            let identity = appIdentity

            return OperationCombiningService<AppAttestAttestation>.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) { [appAttest] in
                let keyId = try keyGenerationOperation.extractNoCancellableResultData()
                let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

                return appAttest.createAttestationWrapper(using: keyId) { attestingKeyId in
                    AttestationProfile2.preimage(
                        purpose: .register,
                        challenge: challenge,
                        clientId: clientId,
                        target: target,
                        bodyDigest: AttestationProfile2.registrationDigest(
                            platform: "ios",
                            appId: identity.appId,
                            attestationType: "app_attest",
                            keyReference: attestingKeyId,
                            appAttestEnvironment: identity.environment
                        )
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
            let target = requestTarget

            return OperationCombiningService<AppAttestAssertion>.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) { [appAttest] in
                let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()

                return appAttest.createAssertionWrapper(keyId: attestation.keyId) {
                    let challenge = try challengeWrapper.targetOperation
                        .extractNoCancellableResultData()

                    return AttestationProfile2.preimage(
                        purpose: .request,
                        challenge: challenge,
                        clientId: clientId,
                        target: target,
                        bodyDigest: AttestationProfile2.bodyDigest(body)
                    )
                }
            }
        }

        func createFixtureOperation(
            clientId: String,
            registerTarget: AttestationRequestTarget,
            attestChallengeWrapper: CompoundOperationWrapper<String>,
            assertChallengeWrapper: CompoundOperationWrapper<String>,
            attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>,
            assertionWrapper: CompoundOperationWrapper<AppAttestAssertion>
        ) -> BaseOperation<AnalyticsAttestationFixture> {
            let body = Self.sampleBody
            let identity = appIdentity
            let target = requestTarget

            return ClosureOperation<AnalyticsAttestationFixture> {
                let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()
                let assertion = try assertionWrapper.targetOperation.extractNoCancellableResultData()
                let attestChallenge = try attestChallengeWrapper.targetOperation
                    .extractNoCancellableResultData()
                let assertChallenge = try assertChallengeWrapper.targetOperation
                    .extractNoCancellableResultData()

                return AnalyticsAttestationFixture(
                    profile: AttestationProfile2.version,
                    clientId: clientId,
                    appId: identity.appId,
                    appAttestEnvironment: identity.environment,
                    keyId: attestation.keyId,
                    attestationChallenge: attestChallenge,
                    attestationTarget: .init(registerTarget),
                    attestationBase64: attestation.attestation.base64EncodedString(),
                    assertionChallenge: assertChallenge,
                    assertionTarget: .init(target),
                    bodyBase64: body.base64EncodedString(),
                    assertionBase64: assertion.base64EncodedString()
                )
            }
        }
    }

#endif
