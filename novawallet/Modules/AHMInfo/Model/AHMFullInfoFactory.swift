import Foundation
import Operation_iOS

protocol AHMFullInfoFactoryProtocol {
    func fetch(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AHMFullInfo?>
}

final class AHMFullInfoFactory {
    private let chainRegistry: ChainRegistryProtocol
    private let repository: AHMInfoRepositoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        repository: AHMInfoRepositoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.repository = repository
    }
}

// MARK: - AHMFullInfoFactoryProtocol

extension AHMFullInfoFactory: AHMFullInfoFactoryProtocol {
    func fetch(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AHMFullInfo?> {
        let infoFetchWrapper = repository.fetch(by: chainId)

        let mapOperation = ClosureOperation<AHMFullInfo?> { [weak self] in
            guard
                let self,
                let info = try infoFetchWrapper.targetOperation.extractNoCancellableResultData()
            else {
                return nil
            }

            let sourceChain = try chainRegistry.getChainOrError(for: info.sourceData.chainId)
            let destinationChain = try chainRegistry.getChainOrError(for: info.destinationData.chainId)

            guard let asset = sourceChain.asset(for: info.sourceData.assetId) else {
                return nil
            }

            return AHMFullInfo(
                info: info,
                sourceChain: sourceChain,
                destinationChain: destinationChain,
                asset: asset
            )
        }

        mapOperation.addDependency(infoFetchWrapper.targetOperation)

        return infoFetchWrapper.insertingTail(operation: mapOperation)
    }
}
