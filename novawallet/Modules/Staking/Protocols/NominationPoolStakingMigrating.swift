import Foundation
import Operation_iOS
import SubstrateSdk

protocol NominationPoolStakingMigrating: StakingActivityProviding {
    func needsPoolStakingMigration(
        for stakingDelegation: DelegatedStakingPallet.Delegation?,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion: @escaping (Result<Bool, Error>) -> Void
    )
}

extension NominationPoolStakingMigrating {
    func needsPoolStakingMigration(
        for stakingDelegation: DelegatedStakingPallet.Delegation?,
        runtimeProvider: RuntimeCodingServiceProtocol,
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

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: completion
        )
    }
}
