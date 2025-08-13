import Foundation
import Operation_iOS
import NovaCrypto
import SubstrateSdk

protocol SlashesOperationFactoryProtocol {
    func createSlashingSpansOperationForStash(
        _ stashAccount: @escaping () throws -> AccountId,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    )
        -> CompoundOperationWrapper<SlashingSpans?>
    
    func createAllUnappliedSlashesWrapper(
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[UnappliedSlash]>
}

final class SlashesOperationFactory {
    let storageRequestFactory: StorageRequestFactoryProtocol

    init(
        storageRequestFactory: StorageRequestFactoryProtocol
    ) {
        self.storageRequestFactory = storageRequestFactory
    }
}

extension SlashesOperationFactory: SlashesOperationFactoryProtocol {
    func createSlashingSpansOperationForStash(
        _ stashAccount: @escaping () throws -> AccountId,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    )
        -> CompoundOperationWrapper<SlashingSpans?> {
        let runtimeFetchOperation = runtimeService.fetchCoderFactoryOperation()

        let keyParams: () throws -> [AccountId] = {
            let accountId: AccountId = try stashAccount()
            return [accountId]
        }

        let fetchOperation: CompoundOperationWrapper<[StorageResponse<SlashingSpans>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: keyParams,
                factory: {
                    try runtimeFetchOperation.extractNoCancellableResultData()
                }, storagePath: Staking.slashingSpans
            )

        fetchOperation.allOperations.forEach { $0.addDependency(runtimeFetchOperation) }

        let mapOperation = ClosureOperation<SlashingSpans?> {
            do {
                return try fetchOperation.targetOperation.extractNoCancellableResultData().first?.value
            } catch StorageKeyEncodingOperationError.invalidStoragePath {
                // the Staking.SlashingSpans is removed in the lates staking pallet version
                return nil
            }
        }

        mapOperation.addDependency(fetchOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [runtimeFetchOperation] + fetchOperation.allOperations
        )
    }
}
