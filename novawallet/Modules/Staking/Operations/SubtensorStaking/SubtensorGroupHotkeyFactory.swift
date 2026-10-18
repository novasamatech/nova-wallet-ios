import Foundation
import Operation_iOS
import SubstrateSdk

protocol SubtensorGroupHotkeyFactoryProtocol {
    func createInfoWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId],
        netuid: UInt16
    ) -> CompoundOperationWrapper<[AccountId: SubtensorGroupHotkeyInfo]>
}

final class SubtensorGroupHotkeyFactory {
    let runtimeConnectionStore: RuntimeConnectionStoring
    let operationQueue: OperationQueue

    private let requestFactory: StorageRequestFactoryProtocol

    init(runtimeConnectionStore: RuntimeConnectionStoring, operationQueue: OperationQueue) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue

        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }
}

private struct SubtensorCollateralKey: NMapKeyStorageKeyProtocol {
    let netuid: UInt16
    let hotkey: AccountId
    let coldkey: AccountId

    func appendSubkey(to encoder: DynamicScaleEncoding, type: String, index: Int) throws {
        switch index {
        case 0:
            try encoder.append(StringScaleMapper(value: netuid), ofType: type)
        case 1:
            try encoder.append(BytesCodable(wrappedValue: hotkey), ofType: type)
        case 2:
            try encoder.append(BytesCodable(wrappedValue: coldkey), ofType: type)
        default:
            throw CommonError.dataCorruption
        }
    }
}

extension SubtensorGroupHotkeyFactory: SubtensorGroupHotkeyFactoryProtocol {
    func createInfoWrapper(
        coldkey: AccountId,
        hotkeys: [AccountId],
        netuid: UInt16
    ) -> CompoundOperationWrapper<[AccountId: SubtensorGroupHotkeyInfo]> {
        let distinctHotkeys = hotkeys.distinct()

        do {
            let engine = try runtimeConnectionStore.getConnection()
            let codingFactoryOperation = try runtimeConnectionStore.getRuntimeProvider().fetchCoderFactoryOperation()
            let codingFactoryClosure = { try codingFactoryOperation.extractNoCancellableResultData() }

            let ownerWrapper: CompoundOperationWrapper<[StorageResponse<BytesCodable>]> = requestFactory.queryItems(
                engine: engine,
                keyParams: { distinctHotkeys.map { BytesCodable(wrappedValue: $0) } },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.ownerPath,
                options: StorageQueryListOptions()
            )

            let collateralWrapper: CompoundOperationWrapper<[StorageResponse<SubtensorStakingPallet.MinerCollateralState>]>
            collateralWrapper = requestFactory.queryNMapItems(
                engine: engine,
                nParamKeys: {
                    distinctHotkeys.map { SubtensorCollateralKey(netuid: netuid, hotkey: $0, coldkey: coldkey) }
                },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.minerCollateralPath,
                options: StorageQueryListOptions()
            )

            ownerWrapper.addDependency(operations: [codingFactoryOperation])
            collateralWrapper.addDependency(operations: [codingFactoryOperation])

            let mergeOperation = ClosureOperation<[AccountId: SubtensorGroupHotkeyInfo]> {
                let owners = try ownerWrapper.targetOperation.extractNoCancellableResultData()
                let collaterals = try collateralWrapper.targetOperation.extractNoCancellableResultData()

                return zip(distinctHotkeys, zip(owners, collaterals)).reduce(into: [:]) { result, item in
                    result[item.0] = SubtensorGroupHotkeyInfo(
                        owner: item.1.0.value?.wrappedValue,
                        collateral: item.1.1.value?.locked ?? 0
                    )
                }
            }

            mergeOperation.addDependency(ownerWrapper.targetOperation)
            mergeOperation.addDependency(collateralWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: [codingFactoryOperation] + ownerWrapper.allOperations + collateralWrapper.allOperations
            )
        } catch {
            return .createWithError(error)
        }
    }
}
