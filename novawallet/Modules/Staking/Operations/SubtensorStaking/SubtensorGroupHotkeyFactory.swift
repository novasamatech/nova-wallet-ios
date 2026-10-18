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

            let collateralWrapper: CompoundOperationWrapper<[StorageResponse<SubtensorStakingPallet.MinerCollateralState>]>
            collateralWrapper = requestFactory.queryNMapItems(
                engine: engine,
                nParamKeys: {
                    distinctHotkeys.map { SubtensorCollateralKey(netuid: netuid, hotkey: $0, coldkey: coldkey) }
                },
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: SubtensorStakingPallet.minerCollateralPath,
                options: StorageQueryListOptions()
            )

            collateralWrapper.addDependency(operations: [codingFactoryOperation])

            let mergeOperation = ClosureOperation<[AccountId: SubtensorGroupHotkeyInfo]> {
                let collaterals = try collateralWrapper.targetOperation.extractNoCancellableResultData()

                return zip(distinctHotkeys, collaterals).reduce(into: [:]) { result, item in
                    result[item.0] = SubtensorGroupHotkeyInfo(collateral: item.1.value?.locked ?? 0)
                }
            }

            mergeOperation.addDependency(collateralWrapper.targetOperation)

            return collateralWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mergeOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
