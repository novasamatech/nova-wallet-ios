import Foundation
import Operation_iOS
import SubstrateSdk

protocol MythosStakableCollatorOperationFactoryProtocol: CollatorStakingStakableFactoryProtocol {
    func createSelectedCollatorsWrapper(
        _ collatorIds: [AccountId]
    ) -> CompoundOperationWrapper<[CollatorStakingSelectionInfoProtocol]>
}

final class MythosStakableCollatorOperationFactory {
    struct MappingData {
        let collatorResponses: [StorageResponse<MythosStakingPallet.CandidateInfo>]
        let identities: [AccountId: AccountIdentity]
        let rewardsEngine: CollatorStakingRewardCalculatorEngineProtocol
        let minStake: Balance
        let maxStakers: UInt32
    }

    let collatorService: MythosCollatorServiceProtocol
    let rewardsService: CollatorStakingRewardCalculatorServiceProtocol
    let identityFactory: IdentityProxyFactoryProtocol
    let runtimeProvider: RuntimeProviderProtocol
    let connection: JSONRPCEngine

    private let requestFactory: StorageRequestFactoryProtocol

    init(
        collatorService: MythosCollatorServiceProtocol,
        rewardsService: CollatorStakingRewardCalculatorServiceProtocol,
        runtimeProvider: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        identityFactory: IdentityProxyFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.collatorService = collatorService
        self.rewardsService = rewardsService
        self.identityFactory = identityFactory
        self.runtimeProvider = runtimeProvider
        self.connection = connection

        let operationManager = OperationManager(operationQueue: operationQueue)
        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
    }
}

private extension MythosStakableCollatorOperationFactory {
    func createCollatorsInfoWrapper(
        collatorIdsClosure: @escaping () throws -> [AccountId],
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<MythosStakingPallet.CandidateInfo>]> {
        requestFactory.queryItems(
            engine: connection,
            keyParams: {
                try collatorIdsClosure()
            },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: MythosStakingPallet.candidatesPath
        )
    }

    func createMinStakeWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<StorageResponse<StringScaleMapper<Balance>>> {
        requestFactory.queryItem(
            engine: connection,
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: MythosStakingPallet.minStakePath
        )
    }

    func createMaxStakersPerCollatorOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<UInt32> {
        let operation = PrimitiveConstantOperation<UInt32>(
            path: MythosStakingPallet.maxStakersPerCandidatePath
        )

        operation.configurationBlock = {
            do {
                operation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        return operation
    }

    func createMappingDataWrapper(
        collatorIdsClosure: @escaping () throws -> [AccountId],
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<MappingData> {
        let maxStakersOperation = createMaxStakersPerCollatorOperation(
            dependingOn: codingFactoryOperation
        )

        let collatorsInfoWrapper = createCollatorsInfoWrapper(
            collatorIdsClosure: {
                try collatorIdsClosure()
            },
            codingFactoryOperation: codingFactoryOperation
        )

        let identityWrapper = identityFactory.createIdentityWrapperByAccountId {
            try collatorIdsClosure()
        }

        let rewardsEngineOperation = rewardsService.fetchCalculatorOperation()

        let minStakeWrapper = createMinStakeWrapper(dependingOn: codingFactoryOperation)

        let mappingOperation = ClosureOperation<MappingData> {
            let collatorResponses = try collatorsInfoWrapper.targetOperation.extractNoCancellableResultData()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let rewardsEngine = try rewardsEngineOperation.extractNoCancellableResultData()
            let minStakeResponse = try minStakeWrapper.targetOperation.extractNoCancellableResultData()
            let maxStakers = try maxStakersOperation.extractNoCancellableResultData()

            return MappingData(
                collatorResponses: collatorResponses,
                identities: identities,
                rewardsEngine: rewardsEngine,
                minStake: minStakeResponse.value?.value ?? 0,
                maxStakers: maxStakers
            )
        }

        mappingOperation.addDependency(collatorsInfoWrapper.targetOperation)
        mappingOperation.addDependency(identityWrapper.targetOperation)
        mappingOperation.addDependency(rewardsEngineOperation)
        mappingOperation.addDependency(minStakeWrapper.targetOperation)
        mappingOperation.addDependency(maxStakersOperation)

        return minStakeWrapper
            .insertingHead(operations: [rewardsEngineOperation])
            .insertingHead(operations: identityWrapper.allOperations)
            .insertingHead(operations: collatorsInfoWrapper.allOperations)
            .insertingHead(operations: [maxStakersOperation])
            .insertingTail(operation: mappingOperation)
    }
}

extension MythosStakableCollatorOperationFactory: MythosStakableCollatorOperationFactoryProtocol {
    func stakableCollatorsWrapper() -> CompoundOperationWrapper<[CollatorStakingSelectionInfoProtocol]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let selectedCollatorsWrapper = collatorService.fetchStakableCollatorsWrapper()

        let mappingDataWrapper = createMappingDataWrapper(
            collatorIdsClosure: {
                try selectedCollatorsWrapper.targetOperation.extractNoCancellableResultData()
            },
            dependingOn: codingFactoryOperation
        )

        mappingDataWrapper.addDependency(wrapper: selectedCollatorsWrapper)
        mappingDataWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<[CollatorStakingSelectionInfoProtocol]> {
            let selectedCollators = try selectedCollatorsWrapper.targetOperation.extractNoCancellableResultData()
            let mappingData = try mappingDataWrapper.targetOperation.extractNoCancellableResultData()

            return zip(selectedCollators, mappingData.collatorResponses).compactMap { collatorId, response in
                guard let collatorInfo = response.value else {
                    return nil
                }

                // full collators are not stakable anymore
                guard collatorInfo.stakers < mappingData.maxStakers else {
                    return nil
                }

                let apr = try? mappingData.rewardsEngine.calculateAPR(for: collatorId)

                return MythosCollatorSelectionInfo(
                    accountId: collatorId,
                    candidate: collatorInfo,
                    identity: mappingData.identities[collatorId],
                    maxRewardedDelegations: mappingData.maxStakers,
                    minRewardableStake: mappingData.minStake,
                    isElected: true,
                    apr: apr
                )
            }
        }

        mappingOperation.addDependency(mappingDataWrapper.targetOperation)

        return mappingDataWrapper
            .insertingHead(operations: selectedCollatorsWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mappingOperation)
    }

    func createSelectedCollatorsWrapper(
        _ collatorIds: [AccountId]
    ) -> CompoundOperationWrapper<[CollatorStakingSelectionInfoProtocol]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let selectedCollatorsWrapper = collatorService.fetchStakableCollatorsWrapper()

        let mappingDataWrapper = createMappingDataWrapper(
            collatorIdsClosure: {
                collatorIds
            },
            dependingOn: codingFactoryOperation
        )

        mappingDataWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<[CollatorStakingSelectionInfoProtocol]> {
            let electedCollators = try selectedCollatorsWrapper.targetOperation.extractNoCancellableResultData()
            let electedCollatorsSet = Set(electedCollators)
            let mappingData = try mappingDataWrapper.targetOperation.extractNoCancellableResultData()

            return zip(collatorIds, mappingData.collatorResponses).compactMap { collatorId, response in
                let isElected = electedCollatorsSet.contains(collatorId)

                let apr = try? mappingData.rewardsEngine.calculateAPR(for: collatorId)

                return MythosCollatorSelectionInfo(
                    accountId: collatorId,
                    candidate: response.value,
                    identity: mappingData.identities[collatorId],
                    maxRewardedDelegations: mappingData.maxStakers,
                    minRewardableStake: mappingData.minStake,
                    isElected: isElected,
                    apr: apr
                )
            }
        }

        mappingOperation.addDependency(mappingDataWrapper.targetOperation)
        mappingOperation.addDependency(selectedCollatorsWrapper.targetOperation)

        return mappingDataWrapper
            .insertingHead(operations: selectedCollatorsWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mappingOperation)
    }
}
