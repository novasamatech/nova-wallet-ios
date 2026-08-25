import BigInt
import Foundation
import Operation_iOS
import SubstrateSdk

struct SubtensorNetworkInfo: Equatable {
    let minStake: Balance
    let effectiveNominatorMinStake: Balance
    let rootUnlockInterval: UInt64
    let rootClaimableThreshold: Balance
}

protocol SubtensorNetworkInfoFactoryProtocol {
    func createNetworkInfoWrapper() -> CompoundOperationWrapper<SubtensorNetworkInfo>
}

final class SubtensorNetworkInfoFactory {
    let runtimeConnectionStore: RuntimeConnectionStoring
    let operationQueue: OperationQueue

    private let requestFactory: StorageRequestFactoryProtocol

    init(
        runtimeConnectionStore: RuntimeConnectionStoring,
        operationQueue: OperationQueue
    ) {
        self.runtimeConnectionStore = runtimeConnectionStore
        self.operationQueue = operationQueue

        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }
}

extension SubtensorNetworkInfoFactory: SubtensorNetworkInfoFactoryProtocol {
    // swiftlint:disable:next function_body_length
    func createNetworkInfoWrapper() -> CompoundOperationWrapper<SubtensorNetworkInfo> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let engine = try runtimeConnectionStore.getConnection()

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let codingFactoryClosure: () throws -> RuntimeCoderFactoryProtocol = {
                try codingFactoryOperation.extractNoCancellableResultData()
            }

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

            let unlockIntervalWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<UInt64>>>
            unlockIntervalWrapper = requestFactory.queryItem(
                engine: engine,
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.rootStakeUnlockIntervalPath
            )

            unlockIntervalWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

            let minNominatorFactorWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<Balance>>>
            minNominatorFactorWrapper = requestFactory.queryItem(
                engine: engine,
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.nominatorMinRequiredStakePath
            )

            minNominatorFactorWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

            let thresholdWrapper: CompoundOperationWrapper<[StorageResponse<SubtensorStakingPallet.FixedPoint96F32>]>
            thresholdWrapper = requestFactory.queryItems(
                engine: engine,
                keyParams: { [StringScaleMapper(value: SubtensorStakingPallet.rootNetuid)] },
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.rootClaimableThresholdPath,
                options: StorageQueryListOptions()
            )

            thresholdWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

            let mergeOperation = ClosureOperation<SubtensorNetworkInfo> {
                let minStake = try minStakeOperation.extractNoCancellableResultData()

                let rootUnlockInterval = try unlockIntervalWrapper.targetOperation
                    .extractNoCancellableResultData().value?.value ?? 0

                let factor = try minNominatorFactorWrapper.targetOperation
                    .extractNoCancellableResultData().value?.value ?? 0

                let thresholdBits = try thresholdWrapper.targetOperation
                    .extractNoCancellableResultData().first?.value?.bits

                return SubtensorNetworkInfo(
                    minStake: minStake,
                    effectiveNominatorMinStake: SubtensorStakingPreflight.effectiveNominatorMinStake(
                        minStake: minStake,
                        factor: factor
                    ),
                    rootUnlockInterval: rootUnlockInterval,
                    rootClaimableThreshold: SubtensorStakingPreflight.rootClaimableThreshold(
                        fromBits: thresholdBits
                    )
                )
            }

            mergeOperation.addDependency(minStakeOperation)
            mergeOperation.addDependency(unlockIntervalWrapper.targetOperation)
            mergeOperation.addDependency(minNominatorFactorWrapper.targetOperation)
            mergeOperation.addDependency(thresholdWrapper.targetOperation)

            let dependencies = [codingFactoryOperation, minStakeOperation] +
                unlockIntervalWrapper.allOperations +
                minNominatorFactorWrapper.allOperations +
                thresholdWrapper.allOperations

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: dependencies
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
