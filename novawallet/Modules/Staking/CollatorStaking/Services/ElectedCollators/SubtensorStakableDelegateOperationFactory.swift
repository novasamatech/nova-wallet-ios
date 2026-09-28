import Foundation
import Operation_iOS

final class SubtensorStakableDelegateOperationFactory {
    let delegatesService: SubtensorDelegatesServiceProtocol
    let networkInfoFactory: SubtensorNetworkInfoFactoryProtocol
    let workingQueue: DispatchQueue

    init(
        delegatesService: SubtensorDelegatesServiceProtocol,
        networkInfoFactory: SubtensorNetworkInfoFactoryProtocol,
        workingQueue: DispatchQueue = .global()
    ) {
        self.delegatesService = delegatesService
        self.networkInfoFactory = networkInfoFactory
        self.workingQueue = workingQueue
    }
}

extension SubtensorStakableDelegateOperationFactory: CollatorStakingStakableFactoryProtocol {
    func stakableCollatorsWrapper() -> CompoundOperationWrapper<[CollatorStakingSelectionInfoProtocol]> {
        let delegatesOperation: BaseOperation<[SubtensorDelegate]> = AsyncClosureOperation(
            operationClosure: { [weak self] closure in
                guard let self else {
                    throw BaseOperationError.parentOperationCancelled
                }

                delegatesService.fetchDelegates(runningCompletionIn: workingQueue) { result in
                    closure(result)
                }
            },
            cancelationClosure: {}
        )

        let networkInfoWrapper = networkInfoFactory.createNetworkInfoWrapper()

        let mergeOperation = ClosureOperation<[CollatorStakingSelectionInfoProtocol]> {
            let delegates = try delegatesOperation.extractNoCancellableResultData()
            let networkInfo = try networkInfoWrapper.targetOperation.extractNoCancellableResultData()

            return delegates.filter { $0.info.isRegisteredOnRoot }.map { delegate in
                SubtensorDelegateSelectionInfo(
                    delegate: delegate,
                    minStake: max(networkInfo.minStake, networkInfo.effectiveNominatorMinStake)
                )
            }.sorted { $0.totalStake > $1.totalStake }
        }

        mergeOperation.addDependency(delegatesOperation)
        mergeOperation.addDependency(networkInfoWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [delegatesOperation] + networkInfoWrapper.allOperations
        )
    }
}
