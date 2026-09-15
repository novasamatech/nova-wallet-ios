import Foundation
import Operation_iOS
import NovaOperationSupport

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
            // Failed dependencies do not stop dependents; a failed challenge must leave the key unspent.
            _ = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            return try keyIdWrapper.targetOperation.extractNoCancellableResultData()
        }

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

    // Persist before attesting because Apple cannot recover a lost key identifier.
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

            try cacheAttestedKeyId(keyId, epoch: context.epoch)

            return keyId
        }
    }

    // Read the latest retry count so an earlier snapshot cannot reset a concurrent backoff update.
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

            // Preserve the new key even if the retry count cannot be read; lost key IDs are unrecoverable.
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
