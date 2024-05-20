import Foundation
import SubstrateSdk
import RobinHood

struct RawRuntimeMetadata {
    let content: Data
    let isOpaque: Bool
}

protocol RuntimeFetchOperationFactoryProtocol {
    func createMetadataFetchWrapper(
        for connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<RawRuntimeMetadata>
}

final class RuntimeFetchOperationFactory {
    static let availableVersionsCall = "Metadata_metadata_versions"
    static let metadataAtVersionCall = "Metadata_metadata_at_version"
    static let latestSupportedVersion: UInt32 = 15

    let operationQueue: OperationQueue

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }

    private func createVersionedMetadataWrapper(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<Data> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let requestFactory = StateCallRequestFactory(rpcTimeout: JSONRPCTimeout.hour)
        let versionRequestWrapper: CompoundOperationWrapper<[UInt32]> = requestFactory.createWrapper(
            for: Self.availableVersionsCall,
            paramsClosure: nil,
            codingFactoryClosure: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            connection: connection
        )

        versionRequestWrapper.addDependency(operations: [codingFactoryOperation])

        let metadataRequestWrapper = requestFactory.createRawDataWrapper(
            for: Self.metadataAtVersionCall,
            paramsClosure: { encoder, _ in
                let versions = try versionRequestWrapper.targetOperation.extractNoCancellableResultData()
                guard let maxVersion = versions.filter({ $0 <= Self.latestSupportedVersion }).max() else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                try encoder.append(encodable: maxVersion)
            },
            codingFactoryClosure: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            connection: connection
        )

        metadataRequestWrapper.addDependency(wrapper: versionRequestWrapper)

        return metadataRequestWrapper
            .insertingHead(operations: versionRequestWrapper.allOperations)
            .insertingHead(operations: [codingFactoryOperation])
    }

    private func createLegacyMetadataWrapper(for connection: JSONRPCEngine) -> CompoundOperationWrapper<Data> {
        let remoteMetadaOperation = JSONRPCOperation<[String], String>(
            engine: connection,
            method: RPCMethod.getRuntimeMetadata,
            timeout: JSONRPCTimeout.hour
        )

        let mapOperation = ClosureOperation<Data> {
            let hexString = try remoteMetadaOperation.extractNoCancellableResultData()

            return try Data(hexString: hexString)
        }

        mapOperation.addDependency(remoteMetadaOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [remoteMetadaOperation])
    }
}

extension RuntimeFetchOperationFactory: RuntimeFetchOperationFactoryProtocol {
    func createMetadataFetchWrapper(
        for connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<RawRuntimeMetadata> {
        let versionedMetadataWrapper = createVersionedMetadataWrapper(
            for: connection,
            runtimeProvider: runtimeService
        )

        let resultWrapper: CompoundOperationWrapper<RawRuntimeMetadata> = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            do {
                let metadata = try versionedMetadataWrapper.targetOperation.extractNoCancellableResultData()
                let result = RawRuntimeMetadata(content: metadata, isOpaque: true)

                return CompoundOperationWrapper.createWithResult(result)
            } catch {
                let legacyWrapper = self.createLegacyMetadataWrapper(for: connection)

                let mapOperation = ClosureOperation<RawRuntimeMetadata> {
                    let metadata = try legacyWrapper.targetOperation.extractNoCancellableResultData()
                    return RawRuntimeMetadata(content: metadata, isOpaque: false)
                }

                mapOperation.addDependency(legacyWrapper.targetOperation)

                return legacyWrapper.insertingTail(operation: mapOperation)
            }
        }

        resultWrapper.addDependency(wrapper: versionedMetadataWrapper)

        return resultWrapper.insertingHead(operations: versionedMetadataWrapper.allOperations)
    }
}
