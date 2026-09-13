import Foundation
import Operation_iOS
import NovaOperationSupport

/// Attesting a key with Apple and binding it at the gateway.
extension BackendAttestationProvider {
    func createAttestAndRegisterWrapper(
        clientId: String,
        context: AttestationChainContext,
        existingKeyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        let keyIdWrapper = createKeyIdWrapper(context: context, existingKeyId: existingKeyId)

        let challengeWrapper = OperationCombiningService<String>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, remoteFactory] in
            _ = try keyIdWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return remoteFactory.createChallengeWrapper(clientId: clientId, purpose: .register)
        }

        challengeWrapper.addDependency(wrapper: keyIdWrapper)

        let markSpentWrapper = createSaveWrapper(
            isAttested: false,
            isAttestationSpent: true,
            context: context
        ) {
            // The challenge this row is sequenced after, read so its failure actually stops the
            // write: a failed dependency still lets its dependents run, and recording the key as
            // spent when `attestKey` never saw it orphans a Secure Enclave key for good.
            _ = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            return try keyIdWrapper.targetOperation.extractNoCancellableResultData()
        }

        // Sequenced after the challenge, which also keeps the row read as late as possible.
        markSpentWrapper.addDependency(operations: [challengeWrapper.targetOperation])

        let attestationWrapper = createAttestationWrapper(
            clientId: clientId,
            context: context,
            keyIdWrapper: keyIdWrapper,
            challengeWrapper: challengeWrapper
        )

        attestationWrapper.addDependency(wrapper: challengeWrapper)
        attestationWrapper.addDependency(wrapper: markSpentWrapper)

        let registerOperation = createRegisterOperation(
            clientId: clientId,
            context: context,
            challengeWrapper: challengeWrapper,
            attestationWrapper: attestationWrapper
        )

        registerOperation.addDependency(attestationWrapper.targetOperation)

        let saveAttestedWrapper = createSaveWrapper(
            isAttested: true,
            isAttestationSpent: true,
            context: context
        ) {
            try registerOperation.extractNoCancellableResultData()

            return try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId
        }

        saveAttestedWrapper.addDependency(operations: [registerOperation])

        let mapOperation = createCacheOperation(
            context: context,
            attestationWrapper: attestationWrapper,
            saveOperation: saveAttestedWrapper.targetOperation
        )

        mapOperation.addDependency(saveAttestedWrapper.targetOperation)

        let dependencies = keyIdWrapper.allOperations + challengeWrapper.allOperations +
            markSpentWrapper.allOperations + attestationWrapper.allOperations +
            [registerOperation] + saveAttestedWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    /// Apple offers no way to look a key identifier up again, so a freshly minted one is written
    /// before it is attested — otherwise a failed attestation orphans a production key for good.
    func createKeyIdWrapper(
        context: AttestationChainContext,
        existingKeyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        if let existingKeyId {
            return .createWithResult(existingKeyId)
        }

        let generationOperation = appAttest.createKeyGenerationOperation()

        let saveWrapper = createSaveWrapper(
            isAttested: false,
            isAttestationSpent: false,
            context: context
        ) {
            try generationOperation.extractNoCancellableResultData()
        }

        saveWrapper.addDependency(operations: [generationOperation])

        let mapOperation = ClosureOperation<AppAttestKeyId> {
            try saveWrapper.targetOperation.extractNoCancellableResultData()

            return try generationOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(saveWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [generationOperation] + saveWrapper.allOperations
        )
    }

    func createAttestationWrapper(
        clientId: String,
        context: AttestationChainContext,
        keyIdWrapper: CompoundOperationWrapper<AppAttestKeyId>,
        challengeWrapper: CompoundOperationWrapper<String>
    ) -> CompoundOperationWrapper<AppAttestAttestation> {
        OperationCombiningService<AppAttestAttestation>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, appAttest, remoteFactory] in
            let keyId = try keyIdWrapper.targetOperation.extractNoCancellableResultData()
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            // The registration proof commits to the register POST itself, and carries the binding
            // digest where a protected request carries its body digest.
            let target = try remoteFactory.registerTarget()
            let identity = appIdentity

            return appAttest.createAttestationWrapper(using: keyId) { attestingKeyId in
                AttestationProfile2.preimage(
                    purpose: .register,
                    challenge: challenge,
                    clientId: clientId,
                    target: target,
                    bodyDigest: AttestationProfile2.registrationDigest(
                        platform: Constants.platform,
                        appId: identity.appId,
                        attestationType: Constants.attestationType,
                        keyReference: attestingKeyId,
                        appAttestEnvironment: identity.environment
                    )
                )
            }
        }
    }

    func createRegisterOperation(
        clientId: String,
        context: AttestationChainContext,
        challengeWrapper: CompoundOperationWrapper<String>,
        attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>
    ) -> BaseOperation<Void> {
        remoteFactory.createRegisterOperation { [weak self] in
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()
            let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return BackendAttestationRegisterRequest(
                profile: AttestationProfile2.version,
                clientId: clientId,
                challenge: challenge,
                platform: Constants.platform,
                appId: appIdentity.appId,
                attestationType: Constants.attestationType,
                keyReference: attestation.keyId,
                appAttestEnvironment: appIdentity.environment,
                integrityToken: attestation.attestation.base64EncodedString()
            )
        }
    }

    func createCacheOperation(
        context: AttestationChainContext,
        attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>,
        saveOperation: BaseOperation<Void>
    ) -> BaseOperation<AppAttestKeyId> {
        ClosureOperation<AppAttestKeyId> { [weak self] in
            try saveOperation.extractNoCancellableResultData()

            let keyId = try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            cacheAttestedKeyId(keyId)

            return keyId
        }
    }

    /// Writes the row, carrying its persisted `attemptCount` forward so a failure landing after this
    /// save cannot reset the backoff ladder to its first rung.
    ///
    /// The count is fetched here rather than threaded down from the gate's snapshot: the gate reads
    /// the row before the probe leaves the device, and `applyBackoff`'s increment is a fire-and-forget
    /// write that may still be in flight then. Carrying a count onto an attested row is harmless —
    /// `applyBackoff` writes only on an un-attested row and the gate ignores `nextAttemptAt` once a
    /// row is attested — and every attested-to-unattested transition deletes the row rather than
    /// rewriting it, so no episode inherits another's count.
    func createSaveWrapper(
        isAttested: Bool,
        isAttestationSpent: Bool,
        context: AttestationChainContext,
        keyIdClosure: @escaping () throws -> AppAttestKeyId
    ) -> CompoundOperationWrapper<Void> {
        let identifier = context.rowIdentifier

        let fetchOperation = repository.fetchOperation(
            by: { identifier },
            options: RepositoryFetchOptions()
        )

        let saveOperation = repository.saveOperation({ [weak self] in
            let keyId = try keyIdClosure()

            guard let self else {
                return []
            }

            try requireEpoch(context.epoch)

            // A failed read must not abort the write: losing the ladder's position costs one wasted
            // window, while failing to persist a minted key orphans it for good.
            let existing = (try? fetchOperation.extractNoCancellableResultData()) ?? nil

            return [
                AppAttestKeySettings(
                    identifier: identifier,
                    keyId: keyId,
                    isAttested: isAttested,
                    isAttestationSpent: isAttestationSpent,
                    attemptCount: existing?.attemptCount ?? 0,
                    nextAttemptAt: nil
                )
            ]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [fetchOperation]
        )
    }
}
