import Foundation
import Operation_iOS
import SubstrateSdk

protocol UnstakingDurationOperationMaking {
    func createUnstakingDurationWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<UnstakingDuration>

    func createStashDurationVariantWrapper(
        for stashClosure: @escaping () throws -> AccountId,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<UnstakingDurationVariant>
}

final class UnstakingDurationOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
    }

    convenience init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        self.init(
            chainRegistry: chainRegistry,
            storageRequestFactory: storageRequestFactory,
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}

private extension UnstakingDurationOperationFactory {
    static func hasNominatorFastUnbond(_ codingFactory: RuntimeCoderFactoryProtocol) -> Bool {
        codingFactory.hasConstant(for: Staking.nominatorFastUnbondDurationPath) &&
            codingFactory.hasStorage(for: Staking.areNominatorsSlashable)
    }

    func createFullDurationWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<UnstakingDuration> {
        let bondingDurationWrapper: CompoundOperationWrapper<Staking.EraIndex> =
            PrimitiveConstantOperation.wrapper(
                for: Staking.lockUpPeriodPath,
                runtimeService: runtimeProvider
            )

        let mapOperation = ClosureOperation<UnstakingDuration> {
            let bondingDuration = try bondingDurationWrapper.targetOperation
                .extractNoCancellableResultData()

            return UnstakingDuration(validator: bondingDuration, nominator: bondingDuration)
        }

        mapOperation.addDependency(bondingDurationWrapper.targetOperation)

        return bondingDurationWrapper.insertingTail(operation: mapOperation)
    }

    func createFastUnbondDurationWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<UnstakingDuration> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let bondingDurationWrapper: CompoundOperationWrapper<Staking.EraIndex> =
            PrimitiveConstantOperation.wrapper(
                for: Staking.lockUpPeriodPath,
                runtimeService: runtimeProvider
            )

        let fastUnbondDurationWrapper: CompoundOperationWrapper<Staking.EraIndex> =
            PrimitiveConstantOperation.wrapper(
                for: Staking.nominatorFastUnbondDurationPath,
                runtimeService: runtimeProvider
            )

        let slashableWrapper: CompoundOperationWrapper<StorageResponse<Bool>> =
            storageRequestFactory.queryItem(
                engine: connection,
                factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                storagePath: Staking.areNominatorsSlashable
            )

        slashableWrapper.addDependency(operations: [codingFactoryOperation])

        let mergeOperation = ClosureOperation<UnstakingDuration> {
            let bondingDuration = try bondingDurationWrapper.targetOperation
                .extractNoCancellableResultData()
            let fastUnbondDuration = try fastUnbondDurationWrapper.targetOperation
                .extractNoCancellableResultData()

            // unset storage value means the pallet default - nominators are slashable
            let areNominatorsSlashable = try slashableWrapper.targetOperation
                .extractNoCancellableResultData().value ?? true

            let nominatorDuration = areNominatorsSlashable ? bondingDuration : fastUnbondDuration

            return UnstakingDuration(validator: bondingDuration, nominator: nominatorDuration)
        }

        mergeOperation.addDependency(bondingDurationWrapper.targetOperation)
        mergeOperation.addDependency(fastUnbondDurationWrapper.targetOperation)
        mergeOperation.addDependency(slashableWrapper.targetOperation)

        return slashableWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingHead(operations: bondingDurationWrapper.allOperations)
            .insertingHead(operations: fastUnbondDurationWrapper.allOperations)
            .insertingTail(operation: mergeOperation)
    }

    func createFastUnbondVariantWrapper(
        for stashClosure: @escaping () throws -> AccountId,
        runtimeProvider: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<UnstakingDurationVariant> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let bondingDurationWrapper: CompoundOperationWrapper<Staking.EraIndex> =
            PrimitiveConstantOperation.wrapper(
                for: Staking.lockUpPeriodPath,
                runtimeService: runtimeProvider
            )

        let validatorsWrapper: CompoundOperationWrapper<[StorageResponse<Staking.ValidatorPrefs>]> =
            storageRequestFactory.queryItems(
                engine: connection,
                keyParams: { [try stashClosure()] },
                factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                storagePath: Staking.validatorPrefs,
                options: StorageQueryListOptions()
            )

        let lastValidatorEraWrapper: CompoundOperationWrapper<
            [StorageResponse<StringScaleMapper<Staking.EraIndex>>]
        > = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [try stashClosure()] },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: Staking.lastValidatorEra,
            options: StorageQueryListOptions()
        )

        let activeEraWrapper: CompoundOperationWrapper<StorageResponse<Staking.ActiveEraInfo>> =
            storageRequestFactory.queryItem(
                engine: connection,
                factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                storagePath: Staking.activeEra
            )

        validatorsWrapper.addDependency(operations: [codingFactoryOperation])
        lastValidatorEraWrapper.addDependency(operations: [codingFactoryOperation])
        activeEraWrapper.addDependency(operations: [codingFactoryOperation])

        let mergeOperation = ClosureOperation<UnstakingDurationVariant> {
            let validators = try validatorsWrapper.targetOperation.extractNoCancellableResultData()

            // we check actual return data from the node since value can be default one
            if validators.first?.data != nil {
                return .full
            }

            let optLastValidatorEra = try lastValidatorEraWrapper.targetOperation
                .extractNoCancellableResultData().first?.value?.value

            guard let lastValidatorEra = optLastValidatorEra else {
                return .nominator
            }

            let bondingDuration = try bondingDurationWrapper.targetOperation
                .extractNoCancellableResultData()

            guard let activeEra = try activeEraWrapper.targetOperation.extractNoCancellableResultData().value else {
                // can't be validating if no active era
                return .nominator
            }

            return lastValidatorEra + bondingDuration >= activeEra.index ? .full : .nominator
        }

        mergeOperation.addDependency(validatorsWrapper.targetOperation)
        mergeOperation.addDependency(lastValidatorEraWrapper.targetOperation)
        mergeOperation.addDependency(activeEraWrapper.targetOperation)
        mergeOperation.addDependency(bondingDurationWrapper.targetOperation)

        return validatorsWrapper
            .insertingHead(operations: [codingFactoryOperation])
            .insertingHead(operations: lastValidatorEraWrapper.allOperations)
            .insertingHead(operations: activeEraWrapper.allOperations)
            .insertingHead(operations: bondingDurationWrapper.allOperations)
            .insertingTail(operation: mergeOperation)
    }
}

extension UnstakingDurationOperationFactory: UnstakingDurationOperationMaking {
    func createUnstakingDurationWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<UnstakingDuration> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let durationWrapper: CompoundOperationWrapper<UnstakingDuration> =
                OperationCombiningService.compoundNonOptionalWrapper(
                    operationManager: operationManager
                ) {
                    let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                    if Self.hasNominatorFastUnbond(codingFactory) {
                        return self.createFastUnbondDurationWrapper(
                            for: runtimeProvider,
                            connection: connection
                        )
                    } else {
                        return self.createFullDurationWrapper(for: runtimeProvider)
                    }
                }

            durationWrapper.addDependency(operations: [codingFactoryOperation])

            return durationWrapper.insertingHead(operations: [codingFactoryOperation])
        } catch {
            return .createWithError(error)
        }
    }

    func createStashDurationVariantWrapper(
        for stashClosure: @escaping () throws -> AccountId,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<UnstakingDurationVariant> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let variantWrapper: CompoundOperationWrapper<UnstakingDurationVariant> =
                OperationCombiningService.compoundNonOptionalWrapper(
                    operationManager: operationManager
                ) {
                    let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                    if Self.hasNominatorFastUnbond(codingFactory) {
                        return self.createFastUnbondVariantWrapper(
                            for: stashClosure,
                            runtimeProvider: runtimeProvider,
                            connection: connection
                        )
                    } else {
                        return CompoundOperationWrapper.createWithResult(.full)
                    }
                }

            variantWrapper.addDependency(operations: [codingFactoryOperation])

            return variantWrapper.insertingHead(operations: [codingFactoryOperation])
        } catch {
            return .createWithError(error)
        }
    }
}
