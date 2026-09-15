import Foundation
import Operation_iOS
import NovaOperationSupport

extension BackendAttestationProvider {
    func createAttemptWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data,
        contextBox: AttestationChainContextBox,
        epoch: Int
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
                contextBox: contextBox,
                epoch: epoch
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
        contextBox: AttestationChainContextBox,
        epoch: Int
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        switch mode {
        case .unavailable:
            return .createWithError(BackendAttestationError.unsupported)
        case .appAttest:
            break
        }

        // Restrict signing to the configured origin so another host cannot obtain this client's proof.
        guard let gatewayOrigin else {
            logger.error("Gateway URL \(gatewayURL) has no canonical origin; nothing can be attested")

            return .createWithError(BackendAttestationError.unsupported)
        }

        guard target.origin == gatewayOrigin else {
            logger.error("Refusing to attest a request for \(target.origin)")

            return .createWithError(BackendAttestationError.unsupported)
        }

        let context: AttestationChainContext

        do {
            context = try createChainContext(epoch: epoch)
        } catch {
            return .createWithError(error)
        }

        contextBox.store(context)

        return createSignedChainWrapper(
            clientId: context.clientId,
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

    // Check persisted backoff before requesting a challenge to avoid consuming its rate limit.
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

    // Failed dependencies do not stop dependents; create the probe only after the backoff check succeeds.
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

    // Probe registration status before attesting; local state can outlive the remote binding.
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
                // Only an identity rejection requires registration; other failures must propagate.
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

            if let keyId = try attestedKeyId(from: row, epoch: context.epoch) {
                return .createWithResult(
                    AttestationCredentials(challenge: challenge, keyId: keyId)
                )
            }

            // A missing local key requires registration; a binding conflict then retires the identity.
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

    // Request a fresh challenge after attestation, which can outlast the probe's challenge.
    func createRegisteredCredentialsWrapper(
        clientId: String,
        context: AttestationChainContext,
        row: AppAttestKeySettings?
    ) -> CompoundOperationWrapper<AttestationCredentials> {
        // Apple attests each key only once.
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
