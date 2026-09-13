import Foundation
import Operation_iOS
import NovaOperationSupport

/// Building the proof a single protected request travels with.
extension BackendAttestationProvider {
    /// One full signing attempt. `contextBox` carries out what its failure handler learned: which
    /// identity ran, and whether that identity was retired.
    func createAttemptWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data,
        contextBox: AttestationChainContextBox
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let wrapper = OperationCombiningService<[AttestationHeaderKey: String]?>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BackendAttestationError.unsupported
            }

            return createHeadersWrapper(
                target: target,
                bodyClosure: bodyClosure,
                contextBox: contextBox
            )
        }

        let resultOperation = ClosureOperation<[AttestationHeaderKey: String]?> { [weak self] in
            do {
                return try wrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                if self?.handleFailure(error, context: contextBox.value) == true {
                    contextBox.markRetired()
                }

                throw error
            }
        }

        resultOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: resultOperation)
    }

    func createHeadersWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data,
        contextBox: AttestationChainContextBox
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        guard !isRejectedForProcess else {
            return .createWithError(
                BackendAttestationError.rejected(statusCode: Constants.rejectedStatusCode)
            )
        }

        switch mode {
        case .unavailable:
            return .createWithError(BackendAttestationError.unsupported)
        case .appAttest:
            break
        }

        // The proof does not name its destination yet, so refusing an off-gateway target here is
        // what keeps an assertion minted for this client from being spent against another host.
        guard let gatewayOrigin else {
            logger.error("Gateway URL \(gatewayURL) has no canonical origin; nothing can be attested")

            return .createWithError(BackendAttestationError.unsupported)
        }

        guard target.origin == gatewayOrigin else {
            logger.error("Refusing to attest a request for \(target.origin)")

            return .createWithError(BackendAttestationError.unsupported)
        }

        let epoch = identity.consentEpoch

        guard let clientId = identity.clientId(), identity.consentEpoch == epoch else {
            return .createWithError(BackendAttestationError.unsupported)
        }

        let context = AttestationChainContext(
            clientId: clientId,
            rowIdentifier: rowIdentifier(for: clientId),
            epoch: epoch
        )

        contextBox.store(context)

        return createSignedChainWrapper(
            clientId: clientId,
            context: context,
            target: target,
            bodyClosure: bodyClosure
        )
    }

    func createSignedChainWrapper(
        clientId: String,
        context: AttestationChainContext,
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let credentialsWrapper = createCredentialsWrapper(clientId: clientId, context: context)

        let assertionWrapper = OperationCombiningService<AppAttestAssertion>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, appAttest] in
            let credentials = try credentialsWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return appAttest.createAssertionWrapper(keyId: credentials.keyId) {
                let body = try bodyClosure()

                return AttestationProfile2.preimage(
                    purpose: .request,
                    challenge: credentials.challenge,
                    clientId: clientId,
                    target: target,
                    bodyDigest: AttestationProfile2.bodyDigest(body)
                )
            }
        }

        assertionWrapper.addDependency(wrapper: credentialsWrapper)

        let mapOperation = ClosureOperation<[AttestationHeaderKey: String]?> {
            let credentials = try credentialsWrapper.targetOperation.extractNoCancellableResultData()
            let assertion = try assertionWrapper.targetOperation.extractNoCancellableResultData()

            return [
                .profile: String(AttestationProfile2.version),
                .clientId: clientId,
                .challenge: credentials.challenge,
                .appAttestAssertion: assertion.base64EncodedString()
            ]
        }

        mapOperation.addDependency(assertionWrapper.targetOperation)

        return assertionWrapper
            .insertingHead(operations: credentialsWrapper.allOperations)
            .insertingTail(operation: mapOperation)
    }

    /// The persisted window, read before anything leaves the device: a challenge spent behind an
    /// open backoff would only be refused again, and it still costs the gateway's rate limit.
    func createGateOperation(
        context: AttestationChainContext,
        fetchOperation: BaseOperation<AppAttestKeySettings?>
    ) -> BaseOperation<AppAttestKeySettings?> {
        let gateOperation = ClosureOperation<AppAttestKeySettings?> { [weak self] in
            let stored = try fetchOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            let row = try resolveRow(stored, epoch: context.epoch)

            if
                let row,
                !row.isAttested,
                let nextAttemptAt = row.nextAttemptAt,
                isBackoffActive(until: nextAttemptAt) {
                throw BackendAttestationError.retryLater(until: nextAttemptAt)
            }

            return row
        }

        gateOperation.addDependency(fetchOperation)

        return gateOperation
    }

    /// The gateway's verdict on whether this installation is still registered.
    ///
    /// Built inside the closure rather than up front: a failed dependency still lets its dependents
    /// run, so a probe created eagerly would reach the gateway straight through an open backoff.
    func createProbeWrapper(
        clientId: String,
        context: AttestationChainContext,
        gateOperation: BaseOperation<AppAttestKeySettings?>
    ) -> CompoundOperationWrapper<String> {
        let probeWrapper = OperationCombiningService<String>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, remoteFactory] in
            _ = try gateOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return remoteFactory.createChallengeWrapper(clientId: clientId, purpose: .request)
        }

        probeWrapper.addDependency(operations: [gateOperation])

        return probeWrapper
    }

    /// Asks the gateway for a request challenge before any App Attest work happens.
    ///
    /// Registration is what the gateway asks for when it answers `unknown_client`, never something
    /// this client decides for itself from local state: a challenge it grants means the installation
    /// is still bound, and the key that binding names answers it with no attestation at all. The
    /// cost of reading the verdict from the gateway rather than from disk is one refused challenge
    /// on the first request of an unregistered install.
    func createCredentialsWrapper(
        clientId: String,
        context: AttestationChainContext
    ) -> CompoundOperationWrapper<AttestationCredentials> {
        let identifier = context.rowIdentifier

        let fetchOperation = repository.fetchOperation(
            by: { identifier },
            options: RepositoryFetchOptions()
        )

        let gateOperation = createGateOperation(context: context, fetchOperation: fetchOperation)

        let probeWrapper = createProbeWrapper(
            clientId: clientId,
            context: context,
            gateOperation: gateOperation
        )

        let resolveWrapper = OperationCombiningService<AttestationCredentials>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            let row = try gateOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            let challenge: String

            do {
                challenge = try probeWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                // A request challenge names the client, so the only verdict here that means "not
                // registered" is the identity-bearing 401. Anything else — a policy refusal, a
                // transport failure — is not an invitation to attest.
                guard
                    let attestationError = error as? BackendAttestationError,
                    case .unauthorized = attestationError
                else {
                    throw error
                }

                return createRegisteredCredentialsWrapper(
                    clientId: clientId,
                    context: context,
                    row: row
                )
            }

            if let keyId = attestedKeyId(from: row) {
                return .createWithResult(
                    AttestationCredentials(challenge: challenge, keyId: keyId)
                )
            }

            // Bound at the gateway but with no key left here, so the binding cannot be answered.
            // Registering is the only way back, and a binding that really does survive answers it
            // with the conflict this provider retires the installation on.
            return createRegisteredCredentialsWrapper(
                clientId: clientId,
                context: context,
                row: row
            )
        }

        resolveWrapper.addDependency(wrapper: probeWrapper)

        return resolveWrapper.insertingHead(
            operations: [fetchOperation, gateOperation] + probeWrapper.allOperations
        )
    }

    /// Registers, then takes the challenge the proof actually travels with: the probe's own
    /// challenge was either refused outright or has been outlived by `attestKey`.
    func createRegisteredCredentialsWrapper(
        clientId: String,
        context: AttestationChainContext,
        row: AppAttestKeySettings?
    ) -> CompoundOperationWrapper<AttestationCredentials> {
        // Apple attests a key once: a row whose attestation was already spent needs a new key, not a
        // second attestKey call that can only fail.
        let reusableKeyId = row?.isAttestationSpent == true ? nil : row?.keyId

        let registerWrapper = createAttestAndRegisterWrapper(
            clientId: clientId,
            context: context,
            existingKeyId: reusableKeyId
        )

        let challengeWrapper = OperationCombiningService<String>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, remoteFactory] in
            _ = try registerWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return remoteFactory.createChallengeWrapper(clientId: clientId, purpose: .request)
        }

        challengeWrapper.addDependency(wrapper: registerWrapper)

        let mapOperation = ClosureOperation<AttestationCredentials> {
            let keyId = try registerWrapper.targetOperation.extractNoCancellableResultData()
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            return AttestationCredentials(challenge: challenge, keyId: keyId)
        }

        mapOperation.addDependency(challengeWrapper.targetOperation)

        return challengeWrapper
            .insertingHead(operations: registerWrapper.allOperations)
            .insertingTail(operation: mapOperation)
    }
}
