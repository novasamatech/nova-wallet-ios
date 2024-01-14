import Foundation
import SubstrateSdk
import RobinHood

protocol ExposurePageEraOperationFactoryProtocol {
    func createWrapper(
        for eraRangeClosure: @escaping () throws -> EraRange,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<EraIndex?>
}

final class ExposurePageEraOperationFactory {
    let operationQueue: OperationQueue

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }
}

extension ExposurePageEraOperationFactory: ExposurePageEraOperationFactoryProtocol {
    func createWrapper(
        for eraRangeClosure: @escaping () throws -> EraRange,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<EraIndex> {
        let searchService = OperationSearchService<EraIndex, UInt?>(
            paramsClosure: {
                let eraRange = try eraRangeClosure()
                return Array(eraRange.start ... eraRange.end)
            },
            fetchFactory: { eraIndex in
                do {
                    let codingFactory = try codingFactoryClosure()

                    let encodingOperation = MapKeyEncodingOperation(
                        path: Staking.eraStakersOverview,
                        storageKeyFactory: StorageKeyFactory(),
                        keyParams: [StringScaleMapper(value: eraIndex)]
                    )

                    encodingOperation.codingFactory = codingFactory

                    let storageSizeOperation = JSONRPCListOperation<UInt?>(
                        engine: connection,
                        method: RemoteStorageSize.method
                    )

                    storageSizeOperation.configurationBlock = {
                        do {
                            if let key = try encodingOperation.extractNoCancellableResultData().first {
                                storageSizeOperation.parameters = [key.toHex(includePrefix: true)]
                            } else {
                                storageSizeOperation.result = .failure(CommonError.dataCorruption)
                            }
                        } catch {
                            storageSizeOperation.result = .failure(error)
                        }
                    }

                    storageSizeOperation.addDependency(encodingOperation)

                    return CompoundOperationWrapper(
                        targetOperation: storageSizeOperation,
                        dependencies: [encodingOperation]
                    )
                } catch {
                    return CompoundOperationWrapper.createWithError(error)
                }
            },
            evalClosure: { optStorageSize in
                let storageSize = optStorageSize ?? 0
                return storageSize == 0
            },
            operationQueue: operationQueue
        )

        let operation = LongrunOperation(longrun: AnyLongrun(longrun: searchService))

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
