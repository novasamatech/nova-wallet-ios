import BigInt
import Foundation
import Operation_iOS
import SubstrateSdk

struct SubtensorStakingPreflight: Equatable {
    let hotkeyExists: Bool
    let subtokenEnabled: Bool
    let hasColdkeySwapAnnouncement: Bool
    let isSafeModeActive: Bool
    let stakeAvailability: SubtensorStakingPallet.StakeAvailability?
    let rootStakeUnlockInterval: UInt64
    let lastStakeBlock: UInt64?
    let minStake: Balance
    let effectiveNominatorMinStake: Balance
    let rootClaimableThreshold: Balance
    let delegateTake: UInt16
}

extension SubtensorStakingPreflight {
    // NominatorMinRequiredStake stores a per-million factor of the min stake constant, not raos
    static func effectiveNominatorMinStake(minStake: Balance, factor: Balance) -> Balance {
        minStake * factor / BigUInt(1_000_000)
    }

    static func rootClaimableThreshold(fromBits bits: Balance?) -> Balance {
        guard let bits else {
            return SubtensorStakingPallet.defaultRootClaimableThreshold
        }

        return bits >> SubtensorStakingPallet.fixedPointFractionalBits
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
    let operationFactory: SubtensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue

    private let requestFactory: StorageRequestFactoryProtocol

    init(
        runtimeConnectionStore: RuntimeConnectionStoring,
        operationFactory: SubtensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue

        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }
}

private extension SubtensorPreflightFactory {
    struct StorageReads {
        let owner: CompoundOperationWrapper<[StorageResponse<JSON>]>
        let subtokenEnabled: CompoundOperationWrapper<[StorageResponse<Bool>]>
        let swapAnnouncement: CompoundOperationWrapper<[StorageResponse<JSON>]>
        let safeMode: CompoundOperationWrapper<StorageResponse<JSON>>
        let unlockInterval: CompoundOperationWrapper<StorageResponse<StringScaleMapper<UInt64>>>
        let lastStakeBlock: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt64>>]>
        let minNominatorFactor: CompoundOperationWrapper<StorageResponse<StringScaleMapper<Balance>>>
        let claimableThresholdBits: CompoundOperationWrapper<[StorageResponse<SubtensorStakingPallet.FixedPoint96F32>]>
        let delegateTake: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<UInt16>>]>

        var allOperations: [Operation] {
            owner.allOperations + subtokenEnabled.allOperations + swapAnnouncement.allOperations +
                safeMode.allOperations + unlockInterval.allOperations + lastStakeBlock.allOperations +
                minNominatorFactor.allOperations + claimableThresholdBits.allOperations +
                delegateTake.allOperations
        }

        var targetOperations: [Operation] {
            [
                owner.targetOperation,
                subtokenEnabled.targetOperation,
                swapAnnouncement.targetOperation,
                safeMode.targetOperation,
                unlockInterval.targetOperation,
                lastStakeBlock.targetOperation,
                minNominatorFactor.targetOperation,
                claimableThresholdBits.targetOperation,
                delegateTake.targetOperation
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
            ),
            claimableThresholdBits: requestFactory.queryItems(
                engine: engine,
                keyParams: { [StringScaleMapper(value: SubtensorStakingPallet.rootNetuid)] },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.rootClaimableThresholdPath,
                options: StorageQueryListOptions()
            ),
            delegateTake: requestFactory.queryItems(
                engine: engine,
                keyParams: { [BytesCodable(wrappedValue: hotkey)] },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.delegatesTakePath,
                options: StorageQueryListOptions()
            )
        )
    }

    func createMergeOperation(
        for coldkey: AccountId,
        netuid: UInt16,
        reads: StorageReads,
        minStakeOperation: BaseOperation<Balance>,
        defaultTakeOperation: BaseOperation<UInt16>,
        availabilityWrapper: CompoundOperationWrapper<[SubtensorStakingPallet.ColdkeyStakeAvailability]>
    ) -> ClosureOperation<SubtensorStakingPreflight> {
        ClosureOperation<SubtensorStakingPreflight> {
            let hotkeyExists = try reads.owner.targetOperation
                .extractNoCancellableResultData().first?.data != nil

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

            let thresholdBits = try reads.claimableThresholdBits.targetOperation
                .extractNoCancellableResultData().first?.value?.bits

            let minStake = try minStakeOperation.extractNoCancellableResultData()

            let storedTake = try reads.delegateTake.targetOperation
                .extractNoCancellableResultData().first?.value?.value

            let delegateTake = try storedTake ?? defaultTakeOperation.extractNoCancellableResultData()

            let availability = try availabilityWrapper.targetOperation
                .extractNoCancellableResultData()
                .first { $0.coldkey == coldkey }?
                .subnets
                .first { $0.netuid == netuid }?
                .availability

            return SubtensorStakingPreflight(
                hotkeyExists: hotkeyExists,
                subtokenEnabled: netuid == SubtensorStakingPallet.rootNetuid || subtokenValue,
                hasColdkeySwapAnnouncement: hasAnnouncement,
                isSafeModeActive: isSafeModeActive,
                stakeAvailability: availability,
                rootStakeUnlockInterval: unlockInterval,
                lastStakeBlock: lastStakeBlock,
                minStake: minStake,
                effectiveNominatorMinStake: SubtensorStakingPreflight.effectiveNominatorMinStake(
                    minStake: minStake,
                    factor: factor
                ),
                rootClaimableThreshold: SubtensorStakingPreflight.rootClaimableThreshold(
                    fromBits: thresholdBits
                ),
                delegateTake: delegateTake
            )
        }
    }
}

extension SubtensorPreflightFactory: SubtensorPreflightFactoryProtocol {
    // swiftlint:disable:next function_body_length
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

            let defaultTakeOperation = PrimitiveConstantOperation<UInt16>(
                path: SubtensorStakingPallet.initialDefaultDelegateTakePath
            )

            defaultTakeOperation.configurationBlock = {
                do {
                    defaultTakeOperation.codingFactory = try codingFactoryClosure()
                } catch {
                    defaultTakeOperation.result = .failure(error)
                }
            }

            defaultTakeOperation.addDependency(codingFactoryOperation)

            let availabilityWrapper = operationFactory.createStakeAvailabilityWrapper(
                for: [coldkey],
                netuids: [netuid],
                blockHash: nil
            )

            let mergeOperation = createMergeOperation(
                for: coldkey,
                netuid: netuid,
                reads: reads,
                minStakeOperation: minStakeOperation,
                defaultTakeOperation: defaultTakeOperation,
                availabilityWrapper: availabilityWrapper
            )

            reads.targetOperations.forEach { mergeOperation.addDependency($0) }
            mergeOperation.addDependency(minStakeOperation)
            mergeOperation.addDependency(defaultTakeOperation)
            mergeOperation.addDependency(availabilityWrapper.targetOperation)

            let dependencies = [codingFactoryOperation] + reads.allOperations +
                [minStakeOperation, defaultTakeOperation] + availabilityWrapper.allOperations

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: dependencies
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
