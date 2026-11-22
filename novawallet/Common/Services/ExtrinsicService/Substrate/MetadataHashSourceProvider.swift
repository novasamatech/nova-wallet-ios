import Foundation
import Operation_iOS
import SubstrateSdk

/// The metadata the metadata hash and the proof for a hardware wallet are generated from.
/// RFC-78 defines both over metadata v15, whichever newer version the app decodes the chain with.
struct MetadataHashSource: Equatable {
    static let metadataVersion: UInt32 = 15

    let specVersion: UInt32

    /// `Option<OpaqueMetadata>`: the form `Metadata_metadata_at_version` returns and the shortener accepts
    let metadata: Data
}

extension MetadataHashSource: ScaleCodable {
    func encode(scaleEncoder: ScaleEncoding) throws {
        try specVersion.encode(scaleEncoder: scaleEncoder)
        scaleEncoder.appendRaw(data: metadata)
    }

    init(scaleDecoder: ScaleDecoding) throws {
        specVersion = try UInt32(scaleDecoder: scaleDecoder)
        metadata = try scaleDecoder.readAndConfirm(count: scaleDecoder.remained)
    }
}

enum MetadataHashSourceProviderError: Error {
    /// The runtime has no metadata of the needed version: there is nothing to keep
    case sourceUnavailable
}

protocol MetadataHashSourceProviding {
    /// Produces nil when the runtime doesn't provide the metadata the hash is defined over
    func createFetchWrapper(
        for chainId: ChainModel.Id,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<MetadataHashSource?>
}

/**
 *  While the app decodes a chain with metadata v15 or older the stored runtime metadata is the source, as it
 *  always was. Once the stored metadata is newer, v15 of the same spec version is fetched on the first need
 *  and kept in the runtime files, so the next transactions don't go to the network for it.
 */
final class MetadataHashSourceProvider {
    let metadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let runtimeFetchFactory: RuntimeFetchOperationFactoryProtocol
    let blockHashOperationFactory: BlockHashOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        metadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        runtimeFetchFactory: RuntimeFetchOperationFactoryProtocol,
        blockHashOperationFactory: BlockHashOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.metadataRepositoryFactory = metadataRepositoryFactory
        self.filesOperationFactory = filesOperationFactory
        self.runtimeFetchFactory = runtimeFetchFactory
        self.blockHashOperationFactory = blockHashOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension MetadataHashSourceProvider {
    static func createDefault(
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue
    ) -> MetadataHashSourceProvider {
        MetadataHashSourceProvider(
            metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: storageFacade),
            filesOperationFactory: RuntimeFilesOperationFactory.createDefault(),
            runtimeFetchFactory: RuntimeFetchOperationFactory(operationQueue: operationQueue),
            blockHashOperationFactory: BlockHashOperationFactory(),
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }
}

// MARK: - Private

private extension MetadataHashSourceProvider {
    /// Runtime files are a cache: a file that is missing, unreadable, cut or of another runtime is a miss
    func readStoredSource(from data: Data?, specVersion: UInt32) -> MetadataHashSource? {
        guard
            let data,
            let source = try? MetadataHashSource(scaleDecoder: ScaleDecoder(data: data)),
            source.specVersion == specVersion,
            let version = try? RawRuntimeMetadata(content: source.metadata, isOpaque: true).readMetadataVersion(),
            version == MetadataHashSource.metadataVersion else {
            return nil
        }

        return source
    }

    func createStoredOrRemoteWrapper(
        for chainId: ChainModel.Id,
        specVersion: UInt32,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<MetadataHashSource?> {
        let storedWrapper = filesOperationFactory.fetchMetadataHashSourceOperation(for: chainId)

        let resultWrapper: CompoundOperationWrapper<MetadataHashSource?>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let storedData: Data?

            do {
                storedData = try storedWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                // a cache that can't be read must not stop a transaction: the source is fetched instead
                self.logger.warning("Can't read metadata hash source for \(chainId): \(error)")
                storedData = nil
            }

            if let storedSource = self.readStoredSource(from: storedData, specVersion: specVersion) {
                return .createWithResult(storedSource)
            }

            return self.createRemoteWrapper(for: chainId, specVersion: specVersion, connection: connection)
        }

        resultWrapper.addDependency(wrapper: storedWrapper)

        return resultWrapper.insertingHead(operations: storedWrapper.allOperations)
    }

    func createRemoteWrapper(
        for chainId: ChainModel.Id,
        specVersion: UInt32,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<MetadataHashSource?> {
        let blockHashWrapper = blockHashOperationFactory.createBestBlockHashWrapper(connection: connection)

        // the metadata and the runtime version are read at one block: a source kept under the spec version
        // of another runtime would give a wrong hash until the next runtime upgrade
        let resultWrapper: CompoundOperationWrapper<MetadataHashSource?>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let blockHash = try blockHashWrapper.targetOperation.extractNoCancellableResultData()

            return self.createRemoteWrapper(
                for: chainId,
                specVersion: specVersion,
                connection: connection,
                blockHash: blockHash.toHex(includePrefix: true)
            )
        }

        resultWrapper.addDependency(wrapper: blockHashWrapper)

        return resultWrapper.insertingHead(operations: blockHashWrapper.allOperations)
    }

    func createRemoteWrapper(
        for chainId: ChainModel.Id,
        specVersion: UInt32,
        connection: JSONRPCEngine,
        blockHash: BlockHash
    ) -> CompoundOperationWrapper<MetadataHashSource?> {
        let runtimeVersionOperation = JSONRPCListOperation<RuntimeVersionFull>(
            engine: connection,
            method: RPCMethod.getRuntimeVersion,
            parameters: [blockHash],
            timeout: JSONRPCTimeout.hour
        )

        let metadataWrapper = runtimeFetchFactory.createMetadataFetchWrapper(
            for: chainId,
            connection: connection,
            version: MetadataHashSource.metadataVersion,
            blockHash: blockHash
        )

        let sourceOperation = ClosureOperation<MetadataHashSource?> {
            let runtimeVersion = try runtimeVersionOperation.extractNoCancellableResultData()

            guard runtimeVersion.specVersion == specVersion else {
                throw CommonMetadataShortenerError.invalidMetadata(
                    localVersion: specVersion,
                    remoteVersion: runtimeVersion.specVersion
                )
            }

            guard let rawMetadata = try metadataWrapper.targetOperation.extractNoCancellableResultData() else {
                return nil
            }

            // what was asked for is the only thing worth keeping: the hash of anything else is wrong
            guard try rawMetadata.readMetadataVersion() == UInt8(MetadataHashSource.metadataVersion) else {
                throw CommonMetadataShortenerError.metadataMissing
            }

            return MetadataHashSource(specVersion: specVersion, metadata: rawMetadata.content)
        }

        sourceOperation.addDependency(runtimeVersionOperation)
        sourceOperation.addDependency(metadataWrapper.targetOperation)

        let saveWrapper = filesOperationFactory.saveMetadataHashSourceOperation(for: chainId) {
            guard let source = try sourceOperation.extractNoCancellableResultData() else {
                throw MetadataHashSourceProviderError.sourceUnavailable
            }

            return try source.scaleEncoded()
        }

        saveWrapper.addDependency(operations: [sourceOperation])

        let resultOperation = ClosureOperation<MetadataHashSource?> {
            let source = try sourceOperation.extractNoCancellableResultData()

            // the source is still good for this transaction when it couldn't be kept: the next one fetches it again
            if source != nil, case let .failure(error) = saveWrapper.targetOperation.result {
                self.logger.warning("Can't store metadata hash source for \(chainId): \(error)")
            }

            return source
        }

        resultOperation.addDependency(saveWrapper.targetOperation)

        let dependencies = [runtimeVersionOperation] + metadataWrapper.allOperations + [sourceOperation] +
            saveWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: resultOperation, dependencies: dependencies)
    }
}

// MARK: - MetadataHashSourceProviding

extension MetadataHashSourceProvider: MetadataHashSourceProviding {
    func createFetchWrapper(
        for chainId: ChainModel.Id,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<MetadataHashSource?> {
        let runtimeMetadataOperation = metadataRepositoryFactory.createRepository().fetchOperation(
            by: { chainId },
            options: RepositoryFetchOptions()
        )

        let resultWrapper: CompoundOperationWrapper<MetadataHashSource?>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            guard let runtimeMetadata = try runtimeMetadataOperation.extractNoCancellableResultData() else {
                throw CommonMetadataShortenerError.metadataMissing
            }

            // metadata whose version can't be read goes to the shortener as before, which reports it
            guard
                let version = try? runtimeMetadata.readMetadataVersion(),
                version > MetadataHashSource.metadataVersion else {
                let source = MetadataHashSource(
                    specVersion: runtimeMetadata.version,
                    metadata: runtimeMetadata.metadata
                )

                return .createWithResult(source)
            }

            return self.createStoredOrRemoteWrapper(
                for: chainId,
                specVersion: runtimeMetadata.version,
                connection: connection
            )
        }

        resultWrapper.addDependency(operations: [runtimeMetadataOperation])

        return resultWrapper.insertingHead(operations: [runtimeMetadataOperation])
    }
}
