import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol GovCommonOperationFactoryProtocol {
    func createTotalIssuanceWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        blockHash: Data?
    ) -> CompoundOperationWrapper<BigUInt>

    func createElectorateWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        blockHash: Data?
    ) -> CompoundOperationWrapper<BigUInt>
}

final class GovCommonOperationFactory: GovCommonOperationFactoryProtocol {
    func createTotalIssuanceWrapper(
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

        let mapOperation = ClosureOperation<BigUInt> {
            try totalWrapper.targetOperation.extractResultData()?.value?.value ?? 0
        }

        mapOperation.addDependency(totalWrapper.targetOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: totalWrapper.allOperations)
    }

    func createElectorateWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        blockHash: Data?
    ) -> CompoundOperationWrapper<BigUInt> {
        let totalWrapper = createTotalIssuanceWrapper(
            dependingOn: codingFactoryOperation,
            requestFactory: requestFactory,
            connection: connection,
            blockHash: blockHash
        )

        let inactiveWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BigUInt>>> =
            requestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .inactiveIssuance,
                at: blockHash
            )

        let mapOperation = ClosureOperation<BigUInt> {
            let totalIssuance = try totalWrapper.targetOperation.extractNoCancellableResultData()
            let inactiveIssuance = (try? inactiveWrapper.targetOperation.extractResultData()?.value?.value) ?? 0

            return totalIssuance > inactiveIssuance ? totalIssuance - inactiveIssuance : 0
        }

        mapOperation.addDependency(totalWrapper.targetOperation)
        mapOperation.addDependency(inactiveWrapper.targetOperation)

        let dependencies = totalWrapper.allOperations + inactiveWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
