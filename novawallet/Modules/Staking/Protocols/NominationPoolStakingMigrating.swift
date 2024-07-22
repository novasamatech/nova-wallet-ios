import Foundation
import Operation_iOS
import SubstrateSdk

protocol NominationPoolStakingMigrating {
    func needsPoolStakingMigration(
        for stakingDelegation: DelegatedStakingPallet.Delegation?,
        runtimeProvider: RuntimeCodingServiceProtocol,
        cancellableStore: CancellableCallStore,
        operationQueue: OperationQueue,
        completion: @escaping (Result<Bool, Error>) -> Void
    )
}

extension NominationPoolStakingMigrating {
    func needsPoolStakingMigration(
        for stakingDelegation: DelegatedStakingPallet.Delegation?,
        runtimeProvider: RuntimeCodingServiceProtocol,
        cancellableStore: CancellableCallStore,
        operationQueue: OperationQueue,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard stakingDelegation == nil else {
            completion(.success(false))
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

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: .main,
            callbackClosure: completion
        )
    }
}
