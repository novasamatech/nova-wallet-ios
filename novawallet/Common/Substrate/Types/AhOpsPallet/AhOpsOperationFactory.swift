import Foundation
import SubstrateSdk
import Operation_iOS

protocol AhOpsOperationFactoryProtocol {
    func fetchContributions(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AhOpsPallet.ContributionMapping>
}

final class AhOpsOperationFactory {
    let chainRegistry: ChainRegistryProtocol

    private let requestFactory: StorageRequestFactoryProtocol

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry

        requestFactory = StorageRequestFactory.createDefault(with: operationQueue)
    }
}

extension AhOpsOperationFactory: AhOpsOperationFactoryProtocol {
    func fetchContributions(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AhOpsPallet.ContributionMapping> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chainId)
            let runtimeService = try chainRegistry.getRuntimeProviderOrError(for: chainId)

            let storagePath = AhOpsPallet.rcCrowdloanContributionPath

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let wrapper: CompoundOperationWrapper<AhOpsPallet.ContributionMapping> = requestFactory.queryByPrefix(
                engine: connection,
                request: UnkeyedRemoteStorageRequest(storagePath: storagePath),
                storagePath: storagePath,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() }
            )

            wrapper.addDependency(operations: [codingFactoryOperation])

            return wrapper.insertingHead(operations: [codingFactoryOperation])
        } catch {
            return .createWithError(error)
        }
    }
}
