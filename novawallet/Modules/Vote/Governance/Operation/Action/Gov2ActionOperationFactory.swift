import Foundation
import SubstrateSdk
import RobinHood

final class Gov2ActionOperationFactory: GovernanceActionOperationFactory {
    private func createStatusFetchWrapper(
        for hash: Data,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<[StorageResponse<Preimage.RequestStatus>]> {
        OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let storagePath: StorageCodingPath

            if codingFactory.hasStorage(for: Preimage.requestStatusForStoragePath) {
                storagePath = Preimage.requestStatusForStoragePath
            } else {
                storagePath = Preimage.statusForStoragePath
            }

            return requestFactory.queryItems(
                engine: connection,
                keyParams: { [BytesCodable(wrappedValue: hash)] },
                factory: { codingFactory },
                storagePath: storagePath
            )
        }
    }

    override func fetchCall(
        for hash: Data,
        connection: JSONRPCEngine,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
        let statusFetchWrapper = createStatusFetchWrapper(
            for: hash,
            requestFactory: requestFactory,
            connection: connection,
            codingFactoryOperation: codingFactoryOperation
        )

        let callKeyParams: () throws -> [Preimage.PreimageKey] = {
            let status = try statusFetchWrapper.targetOperation.extractNoCancellableResultData().first?.value

            guard let length = status?.length, length <= Self.maxFetchCallSize else {
                return []
            }

            return [Preimage.PreimageKey(hash: hash, length: length)]
        }

        let callFetchWrapper: CompoundOperationWrapper<[StorageResponse<BytesCodable>]> = requestFactory.queryItems(
            engine: connection,
            keyParams: callKeyParams,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Preimage.preimageForStoragePath
        )

        callFetchWrapper.addDependency(wrapper: statusFetchWrapper)

        let mappingOperation = ClosureOperation<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
            let callKeys = try callKeyParams()

            guard !callKeys.isEmpty else {
                let optStatus = try statusFetchWrapper.targetOperation.extractNoCancellableResultData().first?.value

                if let length = optStatus?.length {
                    return length > Self.maxFetchCallSize ? .tooLong : nil
                } else {
                    return nil
                }
            }

            let responses = try callFetchWrapper.targetOperation.extractNoCancellableResultData()
            guard let response = responses.first?.value else {
                return nil
            }

            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let decoder = try codingFactory.createDecoder(from: response.wrappedValue)

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

        let dependencies = statusFetchWrapper.allOperations + callFetchWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
    }
}
