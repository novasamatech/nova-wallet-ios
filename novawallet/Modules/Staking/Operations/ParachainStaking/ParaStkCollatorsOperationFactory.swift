import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol ParaStkCollatorsOperationFactoryProtocol {
    func electedCollatorsInfoOperation(
        for collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[CollatorSelectionInfo]>

    func selectedCollatorsInfoOperation(
        for accountIds: [AccountId],
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[CollatorSelectionInfo]>
}

final class ParaStkCollatorsOperationFactory {
    let requestFactory: StorageRequestFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol

    init(
        requestFactory: StorageRequestFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.requestFactory = requestFactory
        self.identityOperationFactory = identityOperationFactory
    }

    // swiftlint:disable:next function_parameter_count
    private func createMappingForSelectedCollatorsOperation(
        for accountIds: [AccountId],
        selectedCollatorsOperation: BaseOperation<SelectedRoundCollators>,
        rewardEngineOperation: BaseOperation<ParaStakingRewardCalculatorEngineProtocol>,
        metadataOperation: BaseOperation<[StorageResponse<ParachainStaking.CandidateMetadata>]>,
        identityOperation: BaseOperation<[AccountAddress: AccountIdentity]>,
        minTechStakeOperation: BaseOperation<BigUInt>,
        maxRewardedDelegationsOperation: BaseOperation<UInt32>,
        chainFormat: ChainFormat
    ) -> BaseOperation<[CollatorSelectionInfo]> {
        ClosureOperation<[CollatorSelectionInfo]> {
            let selectedCollators = try selectedCollatorsOperation.extractNoCancellableResultData()
            let selectedCollatorsDict = selectedCollators.collators.reduce(
                into: [AccountId: CollatorInfo]()
            ) { $0[$1.accountId] = $1 }

            let metadataList = try metadataOperation.extractNoCancellableResultData()

            let identities = try identityOperation.extractNoCancellableResultData()
            let rewardEngine = try rewardEngineOperation.extractNoCancellableResultData()
            let minTechStake = try minTechStakeOperation.extractNoCancellableResultData()
            let maxRewardedDelegations = try maxRewardedDelegationsOperation.extractNoCancellableResultData()

            let commission = selectedCollators.commission

            return try zip(accountIds, metadataList).compactMap { collatorId, metadataResult in
                guard let metadata = metadataResult.value else {
                    return nil
                }

                let address = try collatorId.toAddress(using: chainFormat)
                let collatorSnapshot = selectedCollatorsDict[collatorId]?.snapshot

                let apr = try? rewardEngine.calculateAPR(for: collatorId)

                let identity = identities[address]

                return CollatorSelectionInfo(
                    accountId: collatorId,
                    metadata: metadata,
                    snapshot: collatorSnapshot,
                    identity: identity,
                    apr: apr,
                    commission: commission,
                    minTechStake: minTechStake,
                    maxRewardedDelegations: maxRewardedDelegations
                )
            }
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func createMappingForElectedCollatorsOperation(
        dependingOn selectedCollatorsOperation: BaseOperation<SelectedRoundCollators>,
        rewardEngineOperation: BaseOperation<ParaStakingRewardCalculatorEngineProtocol>,
        metadataOperation: BaseOperation<[StorageResponse<ParachainStaking.CandidateMetadata>]>,
        identityOperation: BaseOperation<[AccountAddress: AccountIdentity]>,
        minTechStakeOperation: BaseOperation<BigUInt>,
        maxRewardedDelegationsOperation: BaseOperation<UInt32>,
        chainFormat: ChainFormat
    ) -> BaseOperation<[CollatorSelectionInfo]> {
        ClosureOperation<[CollatorSelectionInfo]> {
            let selectedCollators = try selectedCollatorsOperation.extractNoCancellableResultData()
            let metadataList = try metadataOperation.extractNoCancellableResultData()
            let identities = try identityOperation.extractNoCancellableResultData()
            let rewardEngine = try rewardEngineOperation.extractNoCancellableResultData()
            let minTechStake = try minTechStakeOperation.extractNoCancellableResultData()
            let maxRewardedDelegations = try maxRewardedDelegationsOperation.extractNoCancellableResultData()

            let commission = selectedCollators.commission

            return try zip(selectedCollators.collators, metadataList).compactMap { collator, metadataResult in
                guard let metadata = metadataResult.value else {
                    return nil
                }

                let address = try collator.accountId.toAddress(using: chainFormat)

                let apr: Decimal = try rewardEngine.calculateAPR(for: collator.accountId)

                let identity = identities[address]

                return CollatorSelectionInfo(
                    accountId: collator.accountId,
                    metadata: metadata,
                    snapshot: collator.snapshot,
                    identity: identity,
                    apr: apr,
                    commission: commission,
                    minTechStake: minTechStake,
                    maxRewardedDelegations: maxRewardedDelegations
                )
            }
        }
    }

    private func createMetadataWrapper(
        for accountIdClosure: @escaping () throws -> [AccountId],
        connection: JSONRPCEngine,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<ParachainStaking.CandidateMetadata>]> {
        requestFactory.queryItems(
            engine: connection,
            keyParams: {
                try accountIdClosure().map { BytesCodable(wrappedValue: $0) }
            }, factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: ParachainStaking.candidateMetadataPath
        )
    }
}

extension ParaStkCollatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol {
    func electedCollatorsInfoOperation(
        for collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[CollatorSelectionInfo]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let selectedCollatorsOperation = collatorService.fetchInfoOperation()
        let rewardEngineOperation = rewardService.fetchCalculatorOperation()

        let metadataWrapper = createMetadataWrapper(
            for: {
                try selectedCollatorsOperation.extractNoCancellableResultData().collators.map(\.accountId)
            },
            connection: connection,
            dependingOn: codingFactoryOperation
        )

        metadataWrapper.addDependency(operations: [codingFactoryOperation, selectedCollatorsOperation])

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: { try selectedCollatorsOperation.extractNoCancellableResultData().collators.map(\.accountId) },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chainFormat
        )

        identityWrapper.addDependency(operations: [selectedCollatorsOperation])

        let minTechStakeOperation: BaseOperation<BigUInt> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.minDelegatorStk,
            dependingOn: codingFactoryOperation
        )

        let maxRewardedDelegationsOperation: BaseOperation<UInt32> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.maxTopDelegationsPerCandidate,
            dependingOn: codingFactoryOperation
        )

        minTechStakeOperation.addDependency(codingFactoryOperation)
        maxRewardedDelegationsOperation.addDependency(codingFactoryOperation)

        let mappingOperation = createMappingForElectedCollatorsOperation(
            dependingOn: selectedCollatorsOperation,
            rewardEngineOperation: rewardEngineOperation,
            metadataOperation: metadataWrapper.targetOperation,
            identityOperation: identityWrapper.targetOperation,
            minTechStakeOperation: minTechStakeOperation,
            maxRewardedDelegationsOperation: maxRewardedDelegationsOperation,
            chainFormat: chainFormat
        )

        mappingOperation.addDependency(rewardEngineOperation)
        mappingOperation.addDependency(metadataWrapper.targetOperation)
        mappingOperation.addDependency(identityWrapper.targetOperation)
        mappingOperation.addDependency(minTechStakeOperation)
        mappingOperation.addDependency(maxRewardedDelegationsOperation)

        let baseOperations = [codingFactoryOperation, selectedCollatorsOperation, rewardEngineOperation,
                              minTechStakeOperation, maxRewardedDelegationsOperation]
        let dependencies = baseOperations + metadataWrapper.allOperations + identityWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    // swiftlint:disable:next function_parameter_count
    func selectedCollatorsInfoOperation(
        for accountIds: [AccountId],
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[CollatorSelectionInfo]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let selectedCollatorsOperation = collatorService.fetchInfoOperation()
        let rewardEngineOperation = rewardService.fetchCalculatorOperation()

        let metadataWrapper = createMetadataWrapper(
            for: { accountIds },
            connection: connection,
            dependingOn: codingFactoryOperation
        )

        metadataWrapper.addDependency(operations: [codingFactoryOperation])

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: { accountIds },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chainFormat
        )

        let minTechStakeOperation: BaseOperation<BigUInt> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.minDelegatorStk,
            dependingOn: codingFactoryOperation
        )

        let maxRewardedDelegationsOperation: BaseOperation<UInt32> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.maxTopDelegationsPerCandidate,
            dependingOn: codingFactoryOperation
        )

        minTechStakeOperation.addDependency(codingFactoryOperation)
        maxRewardedDelegationsOperation.addDependency(codingFactoryOperation)

        let mappingOperation = createMappingForSelectedCollatorsOperation(
            for: accountIds,
            selectedCollatorsOperation: selectedCollatorsOperation,
            rewardEngineOperation: rewardEngineOperation,
            metadataOperation: metadataWrapper.targetOperation,
            identityOperation: identityWrapper.targetOperation,
            minTechStakeOperation: minTechStakeOperation,
            maxRewardedDelegationsOperation: maxRewardedDelegationsOperation,
            chainFormat: chainFormat
        )

        mappingOperation.addDependency(selectedCollatorsOperation)
        mappingOperation.addDependency(rewardEngineOperation)
        mappingOperation.addDependency(metadataWrapper.targetOperation)
        mappingOperation.addDependency(identityWrapper.targetOperation)
        mappingOperation.addDependency(minTechStakeOperation)
        mappingOperation.addDependency(maxRewardedDelegationsOperation)

        let baseOperations = [codingFactoryOperation, selectedCollatorsOperation, rewardEngineOperation,
                              minTechStakeOperation, maxRewardedDelegationsOperation]
        let dependencies = baseOperations + metadataWrapper.allOperations + identityWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}
