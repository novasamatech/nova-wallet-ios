import Foundation
import SubstrateSdk
import Operation_iOS

struct RawRuntimeMetadata {
    let content: Data
    let isOpaque: Bool
}

extension RawRuntimeMetadata: RuntimeContainerSourceProtocol {
    var opaque: Bool { isOpaque }
    var metadata: Data { content }
}

protocol RuntimeFetchOperationFactoryProtocol {
    /// The newest metadata the app supports among the versions the runtime offers
    func createMetadataFetchWrapper(
        for chainId: ChainModel.Id,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<RawRuntimeMetadata>

    /// Metadata of exactly the given version; nil when the runtime doesn't provide it
    func createMetadataFetchWrapper(
        for chainId: ChainModel.Id,
        connection: JSONRPCEngine,
        version: UInt32,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<RawRuntimeMetadata?>
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
        for connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<Data> {
        let requestFactory = StateCallRequestFactory(rpcTimeout: JSONRPCTimeout.hour)
        let versionRequestWrapper: CompoundOperationWrapper<[UInt32]> = requestFactory.createStaticCodingWrapper(
            for: Self.availableVersionsCall,
            paramsClosure: nil,
            connection: connection,
            decoder: StateCallResultFromScaleTypeDecoder(),
            at: nil
        )

        let metadataRequestWrapper: CompoundOperationWrapper<Data> = requestFactory.createStaticCodingWrapper(
            for: Self.metadataAtVersionCall,
            paramsClosure: {
                let versions = try versionRequestWrapper.targetOperation.extractNoCancellableResultData()
                guard let maxVersion = versions.filter({ $0 <= Self.latestSupportedVersion }).max() else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                return try maxVersion.scaleEncoded()
            },
            connection: connection,
            decoder: StateCallRawDataDecoder(),
            at: nil
        )

        metadataRequestWrapper.addDependency(wrapper: versionRequestWrapper)

        return metadataRequestWrapper.insertingHead(operations: versionRequestWrapper.allOperations)
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
        for _: ChainModel.Id,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<RawRuntimeMetadata> {
        let versionedMetadataWrapper = createVersionedMetadataWrapper(for: connection)

        let resultWrapper: CompoundOperationWrapper<RawRuntimeMetadata>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
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

    func createMetadataFetchWrapper(
        for _: ChainModel.Id,
        connection: JSONRPCEngine,
        version: UInt32,
        blockHash: BlockHash?
    ) -> CompoundOperationWrapper<RawRuntimeMetadata?> {
        let requestWrapper: CompoundOperationWrapper<Data> = StateCallRequestFactory(
            rpcTimeout: JSONRPCTimeout.hour
        ).createStaticCodingWrapper(
            for: Self.metadataAtVersionCall,
            paramsClosure: { try version.scaleEncoded() },
            connection: connection,
            decoder: StateCallRawDataDecoder(),
            at: blockHash
        )

        let mapOperation = ClosureOperation<RawRuntimeMetadata?> {
            let rawMetadata = RawRuntimeMetadata(
                content: try requestWrapper.targetOperation.extractNoCancellableResultData(),
                isOpaque: true
            )

            return try rawMetadata.readMetadataVersion() != nil ? rawMetadata : nil
        }

        mapOperation.addDependency(requestWrapper.targetOperation)

        return requestWrapper.insertingTail(operation: mapOperation)
    }
}
