import Foundation
import Operation_iOS
import SubstrateSdk

final class MythosStakableCollatorOperationFactory {
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
    private func createCollatorsInfoWrapper(
        dependingOn selectedIdsOperation: BaseOperation<[AccountId]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<MythosStakingPallet.CandidateInfo>]> {
        requestFactory.queryItems(
            engine: connection,
            keyParams: {
                try selectedIdsOperation.extractNoCancellableResultData()
            },
            factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: MythosStakingPallet.candidatesPath
        )
    }

    private func createMinStakeWrapper(
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

    private func createMaxStakersPerCollatorOperation(
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
}

extension MythosStakableCollatorOperationFactory: CollatorStakingStakableFactoryProtocol {
    // swiftlint:disable:next function_body_length
    func stakableCollatorsWrapper() -> CompoundOperationWrapper<[CollatorStakingSelectionInfoProtocol]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let maxStakersOperation = createMaxStakersPerCollatorOperation(
            dependingOn: codingFactoryOperation
        )

        maxStakersOperation.addDependency(codingFactoryOperation)

        let selectedCollatorsWrapper = collatorService.fetchStakableCollatorsWrapper()

        let collatorsInfoWrapper = createCollatorsInfoWrapper(
            dependingOn: selectedCollatorsWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        collatorsInfoWrapper.addDependency(wrapper: selectedCollatorsWrapper)
        collatorsInfoWrapper.addDependency(operations: [codingFactoryOperation])

        let identityWrapper = identityFactory.createIdentityWrapperByAccountId {
            try selectedCollatorsWrapper.targetOperation.extractNoCancellableResultData()
        }

        identityWrapper.addDependency(wrapper: selectedCollatorsWrapper)

        let rewardsEngineOperation = rewardsService.fetchCalculatorOperation()

        let minStakeWrapper = createMinStakeWrapper(dependingOn: codingFactoryOperation)
        minStakeWrapper.addDependency(operations: [codingFactoryOperation])

        let mappingOperation = ClosureOperation<[CollatorStakingSelectionInfoProtocol]> {
            let selectedCollators = try selectedCollatorsWrapper.targetOperation.extractNoCancellableResultData()
            let collatorResponses = try collatorsInfoWrapper.targetOperation.extractNoCancellableResultData()
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let rewardsEngine = try rewardsEngineOperation.extractNoCancellableResultData()
            let minStakeResponse = try minStakeWrapper.targetOperation.extractNoCancellableResultData()
            let maxStakers = try maxStakersOperation.extractNoCancellableResultData()

            return zip(selectedCollators, collatorResponses).compactMap { collatorId, response in
                guard let collatorInfo = response.value else {
                    return nil
                }

                let apr = try? rewardsEngine.calculateAPR(for: collatorId)

                return MythosCollatorSelectionInfo(
                    accountId: collatorId,
                    candidate: collatorInfo,
                    identity: identities[collatorId],
                    maxRewardedDelegations: maxStakers,
                    minRewardableStake: minStakeResponse.value?.value ?? 0,
                    isElected: true,
                    apr: apr
                )
            }
        }

        mappingOperation.addDependency(selectedCollatorsWrapper.targetOperation)
        mappingOperation.addDependency(collatorsInfoWrapper.targetOperation)
        mappingOperation.addDependency(identityWrapper.targetOperation)
        mappingOperation.addDependency(rewardsEngineOperation)
        mappingOperation.addDependency(minStakeWrapper.targetOperation)
        mappingOperation.addDependency(maxStakersOperation)

        return minStakeWrapper
            .insertingHead(operations: [rewardsEngineOperation])
            .insertingHead(operations: identityWrapper.allOperations)
            .insertingHead(operations: collatorsInfoWrapper.allOperations)
            .insertingHead(operations: selectedCollatorsWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation, maxStakersOperation])
            .insertingTail(operation: mappingOperation)
    }
}