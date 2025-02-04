import Foundation
import Operation_iOS
import SubstrateSdk

struct MythosStakingNetworkInfo {
    let totalStake: Balance
    let minStake: Balance
    let activeStakersCount: Int
}

protocol MythosStkNetworkInfoOperationFactoryProtocol {
    func networkStakingWrapper(
        for collatorService: MythosCollatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<MythosStakingNetworkInfo>
}

final class MythosStkNetworkInfoOperationFactory {
    let requestFactory: StorageRequestFactory
    let keysFetchFactory: StorageKeysOperationFactoryProtocol

    init(operationQueue: OperationQueue) {
        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
        keysFetchFactory = StorageKeysOperationFactory(operationQueue: operationQueue)
    }
}

extension MythosStkNetworkInfoOperationFactory {
    func createMinStakeWrapper(
        for connection: JSONRPCEngine,
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

    func createActiveStakers(
        for connection: JSONRPCEngine,
        dependingOn electedCollatorsOperation: BaseOperation<MythosSessionCollators>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<Set<AccountId>> {
        let delegationsWrapper: CompoundOperationWrapper<[MythosStakingPallet.CandidateStakeKey]>

        delegationsWrapper = keysFetchFactory.createKeysFetchWrapper(
            by: MythosStakingPallet.candidateStakePath,
            codingFactoryClosure: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            connection: connection
        )

        let mappingOperation = ClosureOperation<Set<AccountId>> {
            let keys = try delegationsWrapper.targetOperation.extractNoCancellableResultData()
            let electedCollators = try electedCollatorsOperation.extractNoCancellableResultData()

            let electedCollatorIds = Set(electedCollators.map(\.accountId))

            return keys.reduce(into: Set<AccountId>()) { accum, key in
                if electedCollatorIds.contains(key.candidate) {
                    accum.insert(key.staker)
                }
            }
        }

        mappingOperation.addDependency(delegationsWrapper.targetOperation)

        return delegationsWrapper.insertingTail(operation: mappingOperation)
    }
}

extension MythosStkNetworkInfoOperationFactory: MythosStkNetworkInfoOperationFactoryProtocol {
    func networkStakingWrapper(
        for collatorService: MythosCollatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<MythosStakingNetworkInfo> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let minStakeWrapper = createMinStakeWrapper(
            for: connection,
            dependingOn: codingFactoryOperation
        )

        minStakeWrapper.addDependency(operations: [codingFactoryOperation])

        let electedCollatorsOperation = collatorService.fetchInfoOperation()

        let activeStakersWrapper = createActiveStakers(
            for: connection,
            dependingOn: electedCollatorsOperation,
            codingFactoryOperation: codingFactoryOperation
        )

        activeStakersWrapper.addDependency(operations: [codingFactoryOperation, electedCollatorsOperation])

        let mapOperation = ClosureOperation<MythosStakingNetworkInfo> {
            let electedCollators = try electedCollatorsOperation.extractNoCancellableResultData()
            let minStake = try minStakeWrapper.targetOperation.extractNoCancellableResultData()
            let stakersCount = try activeStakersWrapper.targetOperation.extractNoCancellableResultData().count

            let totalStake = electedCollators.reduce(Balance(0)) { $0 + ($1.info?.stake ?? 0) }

            return MythosStakingNetworkInfo(
                totalStake: totalStake,
                minStake: minStake.value?.value ?? 0,
                activeStakersCount: stakersCount
            )
        }

        mapOperation.addDependency(electedCollatorsOperation)
        mapOperation.addDependency(activeStakersWrapper.targetOperation)
        mapOperation.addDependency(minStakeWrapper.targetOperation)

        return activeStakersWrapper
            .insertingHead(operations: [electedCollatorsOperation])
            .insertingHead(operations: minStakeWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
            .insertingTail(operation: mapOperation)
    }
}
