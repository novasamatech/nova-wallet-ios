import Foundation
import Operation_iOS

protocol NominationPoolInteratorMigrating {
    func provideNeedsMigration(
        for stakingDelegation: DelegatedStakingPallet.Delegation?,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion: @escaping (Bool) -> Void
    )
}

extension NominationPoolInteratorMigrating {
    func provideNeedsMigration(
        for stakingDelegation: DelegatedStakingPallet.Delegation?,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion: @escaping (Bool) -> Void
    ) {
        guard stakingDelegation == nil else {
            completion(false)
            return
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let checkDelegatedStakingOperation = ClosureOperation<Bool> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return codingFactory.hasCall(for: NominationPools.MigrateCall.codingPath) &&
                codingFactory.hasStorage(for: DelegatedStakingPallet.delegatorsPath)
        }

        checkDelegatedStakingOperation.addDependency(codingFactoryOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: checkDelegatedStakingOperation,
            dependencies: [codingFactoryOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            switch result {
            case let .success(needsMigration):
                completion(needsMigration)
            case .failure:
                completion(false)
            }
        }
    }
}
