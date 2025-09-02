import Foundation
import Operation_iOS

protocol MythosCollatorServiceProtocol: StakingCollatorsServiceProtocol & ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<MythosSessionCollators>
}

extension MythosCollatorServiceProtocol {
    func fetchStakableCollatorsWrapper() -> CompoundOperationWrapper<[AccountId]> {
        let fetchOperation = fetchInfoOperation()

        let mappingOperation = ClosureOperation<[AccountId]> {
            let collators = try fetchOperation.extractNoCancellableResultData()

            return collators.compactMap { $0.info != nil ? $0.accountId : nil }
        }

        mappingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [fetchOperation]
        )
    }
}
