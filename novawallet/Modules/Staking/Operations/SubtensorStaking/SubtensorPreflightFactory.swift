import BigInt
import Foundation
import Operation_iOS
import SubstrateSdk

struct SubtensorStakingPreflight: Equatable {
    let hotkeyExists: Bool
    let subnetExists: Bool
    let subtokenEnabled: Bool
    let hasColdkeySwapAnnouncement: Bool
    let isSafeModeActive: Bool
    let rootStakeUnlockInterval: UInt64
    let lastStakeBlock: UInt64?
    let minStake: Balance
    let effectiveNominatorMinStake: Balance
    let blockTime: BlockTime
    var hotkeyOwner: AccountId?
}

extension SubtensorStakingPreflight {
    static func effectiveNominatorMinStake(minStake: Balance, perMillionFactor: Balance) -> Balance {
        minStake * perMillionFactor / BigUInt(1_000_000)
    }
}

protocol SubtensorPreflightFactoryProtocol {
    func createPreflightWrapper(
        for coldkey: AccountId,
        hotkey: AccountId,
        netuid: UInt16
    ) -> CompoundOperationWrapper<SubtensorStakingPreflight>
}

final class SubtensorPreflightFactory {
    let runtimeConnectionStore: RuntimeConnectionStoring
    let blockTimeOperationFactory: BlockTimeOperationFactoryProtocol
    let operationQueue: OperationQueue

    private let requestFactory: StorageRequestFactoryProtocol

    init(
        runtimeConnectionStore: RuntimeConnectionStoring,
        blockTimeOperationFactory: BlockTimeOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.blockTimeOperationFactory = blockTimeOperationFactory
        self.operationQueue = operationQueue

        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }
}

private extension SubtensorPreflightFactory {
    struct StorageReads {
        let owner: CompoundOperationWrapper<[StorageResponse<BytesCodable>]>
        let networksAdded: CompoundOperationWrapper<[StorageResponse<Bool>]>
        let subtokenEnabled: CompoundOperationWrapper<[StorageResponse<Bool>]>
        let swapAnnouncement: CompoundOperationWrapper<[StorageResponse<JSON>]>
        let safeMode: CompoundOperationWrapper<StorageResponse<JSON>>
        let unlockInterval: CompoundOperationWrapper<StorageResponse<StringScaleMapper<UInt64>>>
        let lastStakeBlock: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt64>>]>
        let minNominatorFactor: CompoundOperationWrapper<StorageResponse<StringScaleMapper<Balance>>>

        var allOperations: [Operation] {
            owner.allOperations + networksAdded.allOperations + subtokenEnabled.allOperations +
                swapAnnouncement.allOperations + safeMode.allOperations + unlockInterval.allOperations +
                lastStakeBlock.allOperations + minNominatorFactor.allOperations
        }

        var targetOperations: [Operation] {
            [
                owner.targetOperation,
                networksAdded.targetOperation,
                subtokenEnabled.targetOperation,
                swapAnnouncement.targetOperation,
                safeMode.targetOperation,
                unlockInterval.targetOperation,
                lastStakeBlock.targetOperation,
                minNominatorFactor.targetOperation
            ]
        }
    }

    // swiftlint:disable:next function_body_length
    func createStorageReads(
        for coldkey: AccountId,
        hotkey: AccountId,
        netuid: UInt16,
        engine: JSONRPCEngine,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> StorageReads {
        StorageReads(
            owner: requestFactory.queryItems(
                engine: engine,
                keyParams: { [BytesCodable(wrappedValue: hotkey)] },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.ownerPath,
                options: StorageQueryListOptions()
            ),
            networksAdded: requestFactory.queryItems(
                engine: engine,
                keyParams: { [StringScaleMapper(value: netuid)] },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.networksAddedPath,
                options: StorageQueryListOptions()
            ),
            subtokenEnabled: requestFactory.queryItems(
                engine: engine,
                keyParams: { [StringScaleMapper(value: netuid)] },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.subtokenEnabledPath,
                options: StorageQueryListOptions()
            ),
            swapAnnouncement: requestFactory.queryItems(
                engine: engine,
                keyParams: { [BytesCodable(wrappedValue: coldkey)] },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.coldkeySwapAnnouncementsPath,
                options: StorageQueryListOptions()
            ),
            safeMode: requestFactory.queryItem(
                engine: engine,
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.safeModeEnteredUntilPath
            ),
            unlockInterval: requestFactory.queryItem(
                engine: engine,
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.rootStakeUnlockIntervalPath
            ),
            lastStakeBlock: requestFactory.queryItems(
                engine: engine,
                keyParams1: { [BytesCodable(wrappedValue: coldkey)] },
                keyParams2: { [BytesCodable(wrappedValue: hotkey)] },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.lastColdkeyHotkeyStakeBlockPath,
                options: StorageQueryListOptions()
            ),
            minNominatorFactor: requestFactory.queryItem(
                engine: engine,
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.nominatorMinRequiredStakePath
            )
        )
    }

    func createMergeOperation(
        reads: StorageReads,
        minStakeOperation: BaseOperation<Balance>,
        blockTimeOperation: BaseOperation<BlockTime>
    ) -> ClosureOperation<SubtensorStakingPreflight> {
        ClosureOperation<SubtensorStakingPreflight> {
            let ownerResponse = try reads.owner.targetOperation.extractNoCancellableResultData().first
            let hotkeyExists = ownerResponse?.data != nil

            let networksAddedValue = try reads.networksAdded.targetOperation
                .extractNoCancellableResultData().first?.value ?? false

            let subtokenValue = try reads.subtokenEnabled.targetOperation
                .extractNoCancellableResultData().first?.value ?? false

            let hasAnnouncement = try reads.swapAnnouncement.targetOperation
                .extractNoCancellableResultData().first?.data != nil

            let isSafeModeActive = try reads.safeMode.targetOperation
                .extractNoCancellableResultData().data != nil

            let unlockInterval = try reads.unlockInterval.targetOperation
                .extractNoCancellableResultData().value?.value ?? 0

            let lastStakeBlock = try reads.lastStakeBlock.targetOperation
                .extractNoCancellableResultData().first?.value?.value

            let factor = try reads.minNominatorFactor.targetOperation
                .extractNoCancellableResultData().value?.value ?? 0

            let minStake = try minStakeOperation.extractNoCancellableResultData()
            let blockTime = try blockTimeOperation.extractNoCancellableResultData()

            return SubtensorStakingPreflight(
                hotkeyExists: hotkeyExists,
                subnetExists: networksAddedValue,
                subtokenEnabled: subtokenValue,
                hasColdkeySwapAnnouncement: hasAnnouncement,
                isSafeModeActive: isSafeModeActive,
                rootStakeUnlockInterval: unlockInterval,
                lastStakeBlock: lastStakeBlock,
                minStake: minStake,
                effectiveNominatorMinStake: SubtensorStakingPreflight.effectiveNominatorMinStake(
                    minStake: minStake,
                    perMillionFactor: factor
                ),
                blockTime: blockTime,
                hotkeyOwner: hotkeyExists ? ownerResponse?.value?.wrappedValue : nil
            )
        }
    }
}

extension SubtensorPreflightFactory: SubtensorPreflightFactoryProtocol {
    func createPreflightWrapper(
        for coldkey: AccountId,
        hotkey: AccountId,
        netuid: UInt16
    ) -> CompoundOperationWrapper<SubtensorStakingPreflight> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let engine = try runtimeConnectionStore.getConnection()

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let codingFactoryClosure: () throws -> RuntimeCoderFactoryProtocol = {
                try codingFactoryOperation.extractNoCancellableResultData()
            }

            let reads = createStorageReads(
                for: coldkey,
                hotkey: hotkey,
                netuid: netuid,
                engine: engine,
                codingFactoryClosure: codingFactoryClosure
            )

            reads.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

            let minStakeOperation = PrimitiveConstantOperation<Balance>(
                path: SubtensorStakingPallet.initialMinStakePath
            )

            minStakeOperation.configurationBlock = {
                do {
                    minStakeOperation.codingFactory = try codingFactoryClosure()
                } catch {
                    minStakeOperation.result = .failure(error)
                }
            }

            minStakeOperation.addDependency(codingFactoryOperation)

            let blockTimeWrapper = blockTimeOperationFactory.createExpectedBlockTimeWrapper(from: runtimeProvider)

            let mergeOperation = createMergeOperation(
                reads: reads,
                minStakeOperation: minStakeOperation,
                blockTimeOperation: blockTimeWrapper.targetOperation
            )

            reads.targetOperations.forEach { mergeOperation.addDependency($0) }
            mergeOperation.addDependency(minStakeOperation)
            mergeOperation.addDependency(blockTimeWrapper.targetOperation)

            let dependencies = [codingFactoryOperation] + reads.allOperations + [minStakeOperation] +
                blockTimeWrapper.allOperations

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: dependencies
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
