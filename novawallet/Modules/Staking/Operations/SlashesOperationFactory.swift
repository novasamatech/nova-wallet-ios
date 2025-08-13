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
        erasClosure: @escaping () throws -> [Staking.EraIndex]?,
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
            erasClosure: { nil },
            engine: engine,
            runtimeService: runtimeService
        )
    }
}

final class SlashesOperationFactory {
    enum UnappliedSlashesType {
        case syncVersion
        case asyncVersion
    }

    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue

    init(
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.storageRequestFactory = storageRequestFactory
        self.operationQueue = operationQueue
    }
}

private extension SlashesOperationFactory {
    func determineUnappliedSlashesTypeWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<UnappliedSlashesType> {
        let operation = ClosureOperation<UnappliedSlashesType> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let isMap = codingFactory.metadata.isMapStorageKeyOfType(Staking.unappliedSlashes) { _ in true }

            return isMap ? .syncVersion : .asyncVersion
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func unappliedSlashesSyncWrapper(
        eras: [Staking.EraIndex]?,
        engine: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<RelayStkUnappliedSlashes> {
        if let eras {
            let fetchWrapper: CompoundOperationWrapper<[StorageResponse<[Staking.UnappliedSlash]>]>
            fetchWrapper = storageRequestFactory.queryItems(
                engine: engine,
                keyParams: {
                    eras.map { StringCodable(wrappedValue: $0) }
                },
                factory: { codingFactory },
                storagePath: Staking.unappliedSlashes
            )

            let mappingOperation = ClosureOperation<RelayStkUnappliedSlashes> {
                let result = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                return zip(eras, result).reduce(into: RelayStkUnappliedSlashes()) {
                    $0[$1.0] = $1.1.value
                }
            }

            mappingOperation.addDependency(fetchWrapper.targetOperation)

            return fetchWrapper.insertingTail(operation: mappingOperation)
        } else {
            let fetchWrapper: CompoundOperationWrapper<[Staking.UnappliedSlashSyncKey: [Staking.UnappliedSlash]]>

            fetchWrapper = storageRequestFactory.queryByPrefix(
                engine: engine,
                request: UnkeyedRemoteStorageRequest(storagePath: Staking.unappliedSlashes),
                storagePath: Staking.unappliedSlashes,
                factory: { codingFactory }
            )

            let mappingOperation = ClosureOperation<RelayStkUnappliedSlashes> {
                let result = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                return result.reduce(into: RelayStkUnappliedSlashes()) {
                    $0[$1.key.era] = $1.value
                }
            }

            mappingOperation.addDependency(fetchWrapper.targetOperation)

            return fetchWrapper.insertingTail(operation: mappingOperation)
        }
    }

    func unappliedSlashesAsyncWrapper(
        eras: [Staking.EraIndex]?,
        engine: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<RelayStkUnappliedSlashes> {
        let wrapper: CompoundOperationWrapper<[Staking.UnappliedSlashAsyncKey: Staking.UnappliedSlash]>

        wrapper = storageRequestFactory.queryByPrefix(
            engine: engine,
            request: UnkeyedRemoteStorageRequest(storagePath: Staking.unappliedSlashes),
            storagePath: Staking.unappliedSlashes,
            factory: { codingFactory }
        )

        let mappingOperation = ClosureOperation<RelayStkUnappliedSlashes> {
            var result = try wrapper.targetOperation.extractNoCancellableResultData()

            if let eras {
                let erasSet = Set(eras)
                result = result.filter { erasSet.contains($0.key.era) }
            }

            return result.reduce(into: RelayStkUnappliedSlashes()) { accum, keyValue in
                let era = keyValue.key.era
                let prev = accum[era] ?? []

                accum[era] = prev + [keyValue.value]
            }
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: mappingOperation)
    }

    func unappliedSlashesWrapper(
        type: UnappliedSlashesType,
        eras: [Staking.EraIndex]?,
        engine: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<RelayStkUnappliedSlashes> {
        switch type {
        case .syncVersion:
            unappliedSlashesSyncWrapper(eras: eras, engine: engine, codingFactory: codingFactory)
        case .asyncVersion:
            unappliedSlashesAsyncWrapper(eras: eras, engine: engine, codingFactory: codingFactory)
        }
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
        erasClosure: @escaping () throws -> [Staking.EraIndex]?,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<RelayStkUnappliedSlashes> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let determineTypeWrapper = determineUnappliedSlashesTypeWrapper(dependingOn: codingFactoryOperation)

        determineTypeWrapper.addDependency(operations: [codingFactoryOperation])

        let unappliedSlashesWrapper = OperationCombiningService<RelayStkUnappliedSlashes>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let storageType = try determineTypeWrapper.targetOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let era = try erasClosure()

            return self.unappliedSlashesWrapper(
                type: storageType,
                eras: era,
                engine: engine,
                codingFactory: codingFactory
            )
        }

        unappliedSlashesWrapper.addDependency(wrapper: determineTypeWrapper)
        unappliedSlashesWrapper.addDependency(operations: [codingFactoryOperation])

        return unappliedSlashesWrapper
            .insertingHead(operations: determineTypeWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
    }
}
