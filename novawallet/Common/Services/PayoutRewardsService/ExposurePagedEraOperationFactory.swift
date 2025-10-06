import Foundation
import SubstrateSdk
import Operation_iOS

protocol ExposurePagedEraOperationFactoryProtocol {
    func createWrapper(
        for eraRangeClosure: @escaping () throws -> Staking.EraRange,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Staking.EraIndex?>
}

final class ExposurePagedEraOperationFactory {
    let operationQueue: OperationQueue

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }

    private func createSearchWrapper(
        for storagePath: StorageCodingPath,
        eraRangeClosure: @escaping () throws -> Staking.EraRange,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Staking.EraIndex?> {
        let searchService = OperationSearchService<Staking.EraIndex, UInt?>(
            paramsClosure: {
                let eraRange = try eraRangeClosure()
                return Array(eraRange.start ... eraRange.end)
            },
            fetchFactory: { eraIndex in
                do {
                    let codingFactory = try codingFactoryClosure()

                    let encodingOperation = MapKeyEncodingOperation(
                        path: storagePath,
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
                return storageSize > 0
            },
            operationQueue: operationQueue
        )

        let operation = LongrunOperation(longrun: AnyLongrun(longrun: searchService))

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

extension ExposurePagedEraOperationFactory: ExposurePagedEraOperationFactoryProtocol {
    func createWrapper(
        for eraRangeClosure: @escaping () throws -> Staking.EraRange,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Staking.EraIndex?> {
        let searchOperation = OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let codingFactory = try codingFactoryClosure()
            let eraRange = try eraRangeClosure()

            let storagePath = Staking.eraStakersOverview

            if eraRange.start <= eraRange.end, codingFactory.hasStorage(for: storagePath) {
                let wrapper = self.createSearchWrapper(
                    for: storagePath,
                    eraRangeClosure: eraRangeClosure,
                    codingFactoryClosure: codingFactoryClosure,
                    connection: connection
                )

                return [wrapper]
            } else {
                let wrapper = CompoundOperationWrapper<Staking.EraIndex?>.createWithResult(nil)

                return [wrapper]
            }
        }.longrunOperation()

        let mappingOperation = ClosureOperation<Staking.EraIndex?> {
            guard let index = try searchOperation.extractNoCancellableResultData().first else {
                return nil
            }

            return index
        }

        mappingOperation.addDependency(searchOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [searchOperation])
    }
}
