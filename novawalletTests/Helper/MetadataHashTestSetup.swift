import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

/// The real pieces the metadata hash is made of in the app, over an in-memory store, a scratch directory
/// for the runtime files and a scripted node.
struct MetadataHashTestSetup {
    let storageFacade: StorageFacadeProtocol
    let directory: URL
    let operationQueue: OperationQueue

    var filesOperationFactory: RuntimeFilesOperationFactory {
        RuntimeFilesOperationFactory(repository: FileRepository(), directoryPath: directory.path)
    }

    func makeProvider() -> MetadataHashSourceProvider {
        MetadataHashSourceProvider(
            metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: storageFacade),
            filesOperationFactory: filesOperationFactory,
            runtimeFetchFactory: RuntimeFetchOperationFactory(operationQueue: operationQueue),
            blockHashOperationFactory: BlockHashOperationFactory(),
            operationQueue: operationQueue,
            logger: Logger.shared
        )
    }

    func save(_ item: RuntimeMetadataItem) throws {
        let repository = RuntimeMetadataRepositoryFactory(storageFacade: storageFacade).createRepository()
        let operation = repository.saveOperation({ [item] }, { [] })

        operationQueue.addOperations([operation], waitUntilFinished: true)

        try operation.extractNoCancellableResultData()
    }

    func writeStoredSource(_ data: Data, chainId: ChainModel.Id) throws {
        let wrapper = filesOperationFactory.saveMetadataHashSourceOperation(for: chainId) { data }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        try wrapper.targetOperation.extractNoCancellableResultData()
    }

    func readStoredSource(chainId: ChainModel.Id) throws -> MetadataHashSource? {
        let wrapper = filesOperationFactory.fetchMetadataHashSourceOperation(for: chainId)

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData().map {
            try MetadataHashSource(scaleDecoder: ScaleDecoder(data: $0))
        }
    }

    /// A node at the fixture's spec version that offers v14, v15 and v16 and has the real v15 and v16 metadata
    static func makeNode(for fixture: RuntimeMetadataFixture) -> RuntimeMetadataNodeScript {
        RuntimeMetadataNodeScript(
            versions: [14, 15, 16],
            metadataByVersion: [15, 16].reduce(into: [:]) { result, version in
                result[version] = try? fixture.rawMetadata(version: version).content
            },
            runtimeVersion: RuntimeVersionFull(
                specVersion: fixture.specVersion,
                transactionVersion: fixture.transactionVersion,
                specName: fixture.specName
            )
        )
    }

    /// Every call fails: for the paths that must not go to the network
    static func makeUnreachableNode() -> ScriptedJSONRPCEngine {
        ScriptedJSONRPCEngine { _ in
            throw CommonError.undefined
        }
    }
}
