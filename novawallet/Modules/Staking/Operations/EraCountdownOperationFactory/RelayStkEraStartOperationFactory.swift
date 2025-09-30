import Foundation
import Operation_iOS
import SubstrateSdk

protocol RelayStkEraStartOperationFactoryProtocol {
    func createEraStartSessionIndexWrapper(
        activeEraClosure: @escaping () throws -> Staking.ActiveEraInfo,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<Staking.EraIndex>
}

enum RelayStkEraStartOperationFactoryError: Error {
    case noEraMatching
}

final class RelayStkEraStartOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol

    init(chainRegistry: ChainRegistryProtocol, storageRequestFactory: StorageRequestFactoryProtocol) {
        self.chainRegistry = chainRegistry
        self.storageRequestFactory = storageRequestFactory
    }
}

extension RelayStkEraStartOperationFactory: RelayStkEraStartOperationFactoryProtocol {
    func createEraStartSessionIndexWrapper(
        activeEraClosure: @escaping () throws -> Staking.ActiveEraInfo,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<SessionIndex> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let connection = try chainRegistry.getConnectionOrError(for: chainId)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let fetchWrapper: CompoundOperationWrapper<StorageResponse<[Staking.BondedEra]>> =
                storageRequestFactory.queryItem(
                    engine: connection,
                    factory: {
                        try codingFactoryOperation.extractNoCancellableResultData()
                    },
                    storagePath: Staking.bondedEras
                )

            fetchWrapper.addDependency(operations: [codingFactoryOperation])

            let mappingOperation = ClosureOperation<SessionIndex> {
                let activeEra = try activeEraClosure().index

                let bondedEras = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                let optIndex = bondedEras.value?
                    .first { $0.era == activeEra }?
                    .startSessionIndex

                guard let index = optIndex else {
                    throw RelayStkEraStartOperationFactoryError.noEraMatching
                }

                return index
            }

            mappingOperation.addDependency(fetchWrapper.targetOperation)

            return fetchWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
