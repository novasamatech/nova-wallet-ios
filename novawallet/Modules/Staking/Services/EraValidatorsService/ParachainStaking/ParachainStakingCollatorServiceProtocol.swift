import Foundation
import Operation_iOS

protocol ParachainStakingCollatorServiceProtocol: StakingCollatorsServiceProtocol & ApplicationServiceProtocol {
    func fetchInfoOperation() -> BaseOperation<SelectedRoundCollators>
}

extension ParachainStakingCollatorServiceProtocol {
    func fetchStakableCollatorsWrapper() -> CompoundOperationWrapper<[AccountId]> {
        let fetchOperation = fetchInfoOperation()

        let mappingOperation = ClosureOperation<[AccountId]> {
            let collators = try fetchOperation.extractNoCancellableResultData()

            return collators.collators.map(\.accountId)
        }

        mappingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [fetchOperation]
        )
    }
}
