import BigInt
import Foundation
import Operation_iOS
import SubstrateSdk

/// the governance-mutable scalar the root APY engine needs beyond the cached subnets info;
/// `SubnetOwnerCut` is deliberately not read here — it already rides on `SubtensorSubnetsInfo`,
/// and a second read would give the two rate surfaces independently cached copies of one key
struct SubtensorRootAprInputs: Equatable {
    /// raw `SubtensorModule.TaoWeight`, a fraction of `u64::MAX` (subtensor: `lib.rs:1335`)
    let taoWeight: BigUInt
}

protocol SubtensorRootAprOperationFactoryProtocol {
    func createInputsWrapper() -> CompoundOperationWrapper<SubtensorRootAprInputs>
}

final class SubtensorRootAprOperationFactory {
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

extension SubtensorRootAprOperationFactory {
    /// TaoWeight is ValueQuery on chain, so an unset key must fall back to the runtime default
    /// instead of collapsing the APY to zero
    static func makeInputs(taoWeight: UInt64?) -> SubtensorRootAprInputs {
        SubtensorRootAprInputs(
            taoWeight: taoWeight.map { BigUInt($0) } ?? SubtensorStakingPallet.defaultTaoWeight
        )
    }
}

extension SubtensorRootAprOperationFactory: SubtensorRootAprOperationFactoryProtocol {
    func createInputsWrapper() -> CompoundOperationWrapper<SubtensorRootAprInputs> {
        do {
            let runtimeProvider = try runtimeConnectionStore.getRuntimeProvider()
            let engine = try runtimeConnectionStore.getConnection()

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let codingFactoryClosure: () throws -> RuntimeCoderFactoryProtocol = {
                try codingFactoryOperation.extractNoCancellableResultData()
            }

            let taoWeightWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<UInt64>>>
            taoWeightWrapper = requestFactory.queryItem(
                engine: engine,
                factory: codingFactoryClosure,
                storagePath: SubtensorStakingPallet.taoWeightPath
            )

            taoWeightWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

            let mergeOperation = ClosureOperation<SubtensorRootAprInputs> {
                let taoWeight = try taoWeightWrapper.targetOperation
                    .extractNoCancellableResultData().value?.value

                return Self.makeInputs(taoWeight: taoWeight)
            }

            mergeOperation.addDependency(taoWeightWrapper.targetOperation)

            let dependencies = [codingFactoryOperation] + taoWeightWrapper.allOperations

            return CompoundOperationWrapper(
                targetOperation: mergeOperation,
                dependencies: dependencies
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
