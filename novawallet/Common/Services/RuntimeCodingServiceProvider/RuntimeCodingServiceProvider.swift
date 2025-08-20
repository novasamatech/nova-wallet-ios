import Foundation
import SubstrateSdk
import Operation_iOS

protocol RuntimeCodingServiceProviderProtocol {
    func createRuntimeCodingServiceWrapper(
        for chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<RuntimeCodingServiceProtocol>
}

extension RuntimeCodingServiceProviderProtocol {
    func createCoderFactoryWrapper(
        for chainId: ChainModel.Id,
        in operationQueue: OperationQueue
    ) -> CompoundOperationWrapper<RuntimeCoderFactoryProtocol> {
        let runtimeCodingServiceWrapper = createRuntimeCodingServiceWrapper(
            for: chainId
        )

        let codingFactoryWrapper: CompoundOperationWrapper<RuntimeCoderFactoryProtocol>
        codingFactoryWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let codingService = try runtimeCodingServiceWrapper.targetOperation.extractNoCancellableResultData()

            return CompoundOperationWrapper(targetOperation: codingService.fetchCoderFactoryOperation())
        }

        codingFactoryWrapper.addDependency(wrapper: runtimeCodingServiceWrapper)

        return codingFactoryWrapper.insertingHead(operations: runtimeCodingServiceWrapper.allOperations)
    }

    func createDecodingWrapper(
        for callData: Substrate.CallData,
        chainId: ChainModel.Id,
        in operationQueue: OperationQueue
    ) -> CompoundOperationWrapper<JSON> {
        let runtimeCodingServiceWrapper = createRuntimeCodingServiceWrapper(
            for: chainId
        )

        let decodingWrapper: CompoundOperationWrapper<JSON> = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let codingService = try runtimeCodingServiceWrapper.targetOperation.extractNoCancellableResultData()

            return codingService.createDecodingWrapper(
                for: callData,
                of: GenericType.call.name
            )
        }

        decodingWrapper.addDependency(wrapper: runtimeCodingServiceWrapper)

        return decodingWrapper.insertingHead(operations: runtimeCodingServiceWrapper.allOperations)
    }
}

enum RuntimeCodingServiceProviderError: Error {
    case runtimeMetadaUnavailable(chainId: ChainModel.Id)
}
