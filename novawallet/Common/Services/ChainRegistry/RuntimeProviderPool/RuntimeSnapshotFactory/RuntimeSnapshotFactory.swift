import Foundation
import SubstrateSdk
import Operation_iOS

protocol RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for chain: RuntimeProviderChain
    ) -> CompoundOperationWrapper<RuntimeSnapshot?>
}

final class RuntimeSnapshotFactory {
    let chainId: ChainModel.Id
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol

    init(
        chainId: ChainModel.Id,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol
    ) {
        self.chainId = chainId
        self.filesOperationFactory = filesOperationFactory
        self.repository = repository
        self.runtimeTypeRegistryFactory = runtimeTypeRegistryFactory
    }

    private func createChildFactory(
        for typesUsage: ChainModel.TypesUsage
    ) -> RuntimeSnapshotFactoryProtocol {
        switch typesUsage {
        case .onlyCommon:
            RuntimeCommonTypesSnapshotFactory(
                repository: repository,
                runtimeTypeRegistryFactory: runtimeTypeRegistryFactory,
                filesOperationFactory: filesOperationFactory
            )
        case .onlyOwn:
            RuntimeChainTypesSnapshotFactory(
                repository: repository,
                runtimeTypeRegistryFactory: runtimeTypeRegistryFactory,
                filesOperationFactory: filesOperationFactory
            )
        case .both:
            RuntimeCommonAndChainTypesSnapshotFactory(
                repository: repository,
                runtimeTypeRegistryFactory: runtimeTypeRegistryFactory,
                filesOperationFactory: filesOperationFactory
            )
        case .none:
            RuntimeDefaultTypesSnapshotFactory(
                repository: repository,
                runtimeTypeRegistryFactory: runtimeTypeRegistryFactory
            )
        }
    }
}

// MARK: - RuntimeSnapshotFactoryProtocol

extension RuntimeSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for chain: RuntimeProviderChain
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        createChildFactory(for: chain.typesUsage).createRuntimeSnapshotWrapper(for: chain)
    }
}
