import Foundation
import Operation_iOS
import NovaCrypto
import SubstrateSdk

typealias RelayStkUnappliedSlashes = [Staking.EraIndex: [Staking.UnappliedSlash]]

protocol SlashesOperationFactoryProtocol {
    func createSlashingSpansOperationForStash(
        _ stashAccount: @escaping () throws -> AccountId,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Staking.SlashingSpans?>

    func createUnappliedSlashesWrapper(
        activeErasClosure: @escaping () throws -> [Staking.EraIndex]?,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<RelayStkUnappliedSlashes>
}

extension SlashesOperationFactoryProtocol {
    func createAllUnappliedSlashesWrapper(
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<RelayStkUnappliedSlashes> {
        createUnappliedSlashesWrapper(
            activeErasClosure: { nil },
            engine: engine,
            runtimeService: runtimeService
        )
    }
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
    ) -> CompoundOperationWrapper<Staking.SlashingSpans?> {
        let runtimeFetchOperation = runtimeService.fetchCoderFactoryOperation()

        let keyParams: () throws -> [AccountId] = {
            let accountId: AccountId = try stashAccount()
            return [accountId]
        }

        let fetchOperation: CompoundOperationWrapper<[StorageResponse<Staking.SlashingSpans>]> =
            storageRequestFactory.queryItems(
                engine: engine,
                keyParams: keyParams,
                factory: {
                    try runtimeFetchOperation.extractNoCancellableResultData()
                }, storagePath: Staking.slashingSpans
            )

        fetchOperation.allOperations.forEach { $0.addDependency(runtimeFetchOperation) }

        let mapOperation = ClosureOperation<Staking.SlashingSpans?> {
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

    func createUnappliedSlashesWrapper(
        activeErasClosure _: @escaping () throws -> [Staking.EraIndex]?,
        engine _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<RelayStkUnappliedSlashes> {
        .createWithError(CommonError.dataCorruption)
    }
}
