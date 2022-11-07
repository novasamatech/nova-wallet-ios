import Foundation
import RobinHood
import SubstrateSdk
import BigInt

final class Gov1ActionOperationFactory: GovernanceActionOperationFactory {
    let gov2OperationFactory: Gov2ActionOperationFactory

    init(
        gov2OperationFactory: Gov2ActionOperationFactory,
        requestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.gov2OperationFactory = gov2OperationFactory

        super.init(requestFactory: requestFactory, operationQueue: operationQueue)
    }

    private func createDemocracyPreimageWrapper(
        dependingOn keyEncodingOperation: BaseOperation<[Data]>,
        storageSizeOperation: BaseOperation<String>,
        connection: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> BaseOperation<[ReferendumActionLocal.Call<RuntimeCall<JSON>>?]> {
        OperationCombiningService<ReferendumActionLocal.Call<RuntimeCall<JSON>>?>(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let result = try storageSizeOperation.extractNoCancellableResultData()

            if let size = BigUInt.fromHexString(result), size <= Self.maxFetchCallSize {
                let callFetchWrapper: CompoundOperationWrapper<[StorageResponse<Democracy.ProposalCall>]> =
                    self.requestFactory.queryItems(
                        engine: connection,
                        keys: { try keyEncodingOperation.extractNoCancellableResultData() },
                        factory: { codingFactory },
                        storagePath: Democracy.preimages
                    )

                let mappingOperation = ClosureOperation<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
                    let responses = try callFetchWrapper.targetOperation.extractNoCancellableResultData()
                    guard case let .available(call) = responses.first?.value else {
                        return nil
                    }

                    let decoder = try codingFactory.createDecoder(from: call.data)

                    let optCall: RuntimeCall<JSON>? = try? decoder.read(
                        of: GenericType.call.name,
                        with: codingFactory.createRuntimeJsonContext().toRawContext()
                    )

                    if let call = optCall {
                        return .concrete(call)
                    } else {
                        return nil
                    }
                }

                mappingOperation.addDependency(callFetchWrapper.targetOperation)

                let wrapper = CompoundOperationWrapper(
                    targetOperation: mappingOperation,
                    dependencies: callFetchWrapper.allOperations
                )

                return [wrapper]
            } else {
                let wrapper = CompoundOperationWrapper<ReferendumActionLocal.Call<RuntimeCall<JSON>>?>.createWithResult(
                    .tooLong
                )
                return [wrapper]
            }
        }.longrunOperation()
    }

    private func fetchDemocracyPreimage(
        for hash: Data,
        connection: JSONRPCEngine,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
        let keyEncodingOperation = MapKeyEncodingOperation<BytesCodable>(
            path: Democracy.preimages,
            storageKeyFactory: StorageKeyFactory()
        )

        keyEncodingOperation.codingFactory = codingFactory
        keyEncodingOperation.keyParams = [BytesCodable(wrappedValue: hash)]

        let storageSizeOperation = JSONRPCListOperation<String>(engine: connection, method: RemoteStorageSize.method)

        storageSizeOperation.configurationBlock = {
            do {
                if let key = try keyEncodingOperation.extractNoCancellableResultData().first {
                    storageSizeOperation.parameters = [key.toHex(includePrefix: true)]
                } else {
                    storageSizeOperation.result = .failure(CommonError.dataCorruption)
                }
            } catch {
                storageSizeOperation.result = .failure(error)
            }
        }

        storageSizeOperation.addDependency(keyEncodingOperation)

        let combiningOperation = createDemocracyPreimageWrapper(
            dependingOn: keyEncodingOperation,
            storageSizeOperation: storageSizeOperation,
            connection: connection,
            codingFactory: codingFactory
        )

        combiningOperation.addDependency(storageSizeOperation)

        let mappingOperation = ClosureOperation<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
            guard let action = try combiningOperation.extractNoCancellableResultData().first else {
                return nil
            }

            return action
        }

        mappingOperation.addDependency(combiningOperation)

        let dependencies = [keyEncodingOperation, storageSizeOperation, combiningOperation]

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }

    override func fetchCall(
        for hash: Data,
        connection: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
        let fetchOperation = OperationCombiningService<ReferendumActionLocal.Call<RuntimeCall<JSON>>?>(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let callPath = Democracy.preimages
            if codingFactory.metadata.getCall(from: callPath.moduleName, with: callPath.itemName) != nil {
                let wrapper = self.fetchDemocracyPreimage(
                    for: hash,
                    connection: connection,
                    codingFactory: codingFactory
                )

                return [wrapper]
            } else {
                let wrapper = self.gov2OperationFactory.fetchCall(
                    for: hash,
                    connection: connection,
                    codingFactoryOperation: codingFactoryOperation
                )

                return [wrapper]
            }
        }.longrunOperation()

        let mappingOperation = ClosureOperation<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
            guard let action = try fetchOperation.extractNoCancellableResultData().first else {
                return nil
            }

            return action
        }

        mappingOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [fetchOperation])
    }
}
