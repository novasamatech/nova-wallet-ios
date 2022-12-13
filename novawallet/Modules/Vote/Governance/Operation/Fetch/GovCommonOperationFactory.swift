import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol GovCommonOperationFactoryProtocol {
    func createElectorateWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        blockHash: Data?
    ) -> CompoundOperationWrapper<BigUInt>
}

final class GovCommonOperationFactory: GovCommonOperationFactoryProtocol {
    func createElectorateWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        blockHash: Data?
    ) -> CompoundOperationWrapper<BigUInt> {
        let totalWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>> =
            requestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .totalIssuance,
                at: blockHash
            )

        let inactiveWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>> =
            requestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .inactiveIssuance,
                at: blockHash
            )

        let mapOperation = ClosureOperation<BigUInt> {
            let totalIssuance = try totalWrapper.targetOperation.extractResultData()?.value?.value ?? 0
            let inactiveIssuance = (try? inactiveWrapper.targetOperation.extractResultData()?.value?.value) ?? 0

            return totalIssuance > inactiveIssuance ? totalIssuance - inactiveIssuance : 0
        }

        mapOperation.addDependency(totalWrapper.targetOperation)
        mapOperation.addDependency(inactiveWrapper.targetOperation)

        let dependencies = totalWrapper.allOperations + inactiveWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
