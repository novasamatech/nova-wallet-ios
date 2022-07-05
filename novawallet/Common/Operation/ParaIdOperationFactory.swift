import Foundation
import RobinHood
import SubstrateSdk

protocol ParaIdOperationFactoryProtocol {
    func createParaIdOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<ParaId>
}

final class ParaIdOperationFactory: ParaIdOperationFactoryProtocol {
    static let shared = ParaIdOperationFactory(
        chainRegistry: ChainRegistryFacade.sharedRegistry,
        operationQueue: OperationManagerFacade.sharedDefaultQueue
    )

    let chainRegistry: ChainRegistryProtocol

    private var cachedParaIds: [ChainModel.Id: ParaId] = [:]
    private var mutex = NSLock()

    let storageRequestFactory: StorageRequestFactoryProtocol

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry

        let operationManager = OperationManager(operationQueue: operationQueue)
        storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
    }

    private func getParaId(for chainId: ChainModel.Id) -> ParaId? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return cachedParaIds[chainId]
    }

    private func setParaId(_ paraId: ParaId?, for chainId: ChainModel.Id) {
        mutex.lock()

        cachedParaIds[chainId] = paraId

        mutex.unlock()
    }

    func createParaIdOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<ParaId> {
        if let paraId = getParaId(for: chainId) {
            return CompoundOperationWrapper.createWithResult(paraId)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.connectionUnavailable)
        }

        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let wrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<ParaId>>>

        wrapper = storageRequestFactory.queryItem(
            engine: connection,
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .parachainId
        )

        wrapper.addDependency(operations: [coderFactoryOperation])

        let updateOperation = ClosureOperation<ParaId> { [weak self] in
            let response = try wrapper.targetOperation.extractNoCancellableResultData()

            guard let paraId = response.value?.value else {
                throw CommonError.undefined
            }

            self?.setParaId(paraId, for: chainId)

            return paraId
        }

        updateOperation.addDependency(wrapper.targetOperation)

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        return CompoundOperationWrapper(targetOperation: updateOperation, dependencies: dependencies)
    }
}
