import Foundation
import Operation_iOS

protocol NominationPoolsDataProviding {
    func fetchBondedAccounts(
        for operationFactory: NominationPoolsOperationFactoryProtocol,
        poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion closure: @escaping (Result<[NominationPools.PoolId: AccountId], Error>) -> Void
    ) -> CancellableCall
}

extension NominationPoolsDataProviding {
    func fetchBondedAccounts(
        for operationFactory: NominationPoolsOperationFactoryProtocol,
        poolIds: @escaping () throws -> Set<NominationPools.PoolId>,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        completion closure: @escaping (Result<[NominationPools.PoolId: AccountId], Error>) -> Void
    ) -> CancellableCall {
        let wrapper = operationFactory.createBondedAccountsWrapper(
            for: poolIds,
            runtimeService: runtimeService
        )

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                guard !wrapper.targetOperation.isCancelled else {
                    return
                }

                do {
                    let accountIds = try wrapper.targetOperation.extractNoCancellableResultData()
                    closure(.success(accountIds))
                } catch {
                    closure(.failure(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)

        return wrapper
    }
}
