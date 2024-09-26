import Foundation
import Operation_iOS

protocol CrosschainAssetConversionFactoryProtocol {
    func createConversionWrapper(
        from assetLocation: XcmV3.Multilocation
    ) -> CompoundOperationWrapper<ChainAsset?>
}

enum CrosschainAssetConversionError: Error {
    case unexpectedError(String)
    case unsupportedAssetId(XcmV3.Multilocation)
}

final class CrosschainAssetConversionFactory {
    let chainRegistry: ChainRegistryProtocol
    let baseChain: ChainModel
    let operationQueue: OperationQueue

    init(baseChain: ChainModel, chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.baseChain = baseChain
        self.operationQueue = operationQueue
    }

    private func createAssetsPalletWrapper(
        for _: ParaId,
        assetId: AssetConversionPallet.AssetId
    ) -> CompoundOperationWrapper<ChainAsset?> {
        let chainWrapper = chainRegistry.asyncWaitChainWrapper(for: KnowChainId.statemint)

        let coderFactoryWrapper: CompoundOperationWrapper<RuntimeCoderFactoryProtocol>
        coderFactoryWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            guard let chain = try chainWrapper.targetOperation.extractNoCancellableResultData() else {
                throw CrosschainAssetConversionError.unexpectedError("Chain not found")
            }

            guard let provider = self.chainRegistry.getRuntimeProvider(for: chain.chainId) else {
                throw CrosschainAssetConversionError.unexpectedError("Runtime provider not found")
            }

            let operation = provider.fetchCoderFactoryOperation()

            return CompoundOperationWrapper(targetOperation: operation)
        }

        coderFactoryWrapper.addDependency(wrapper: chainWrapper)

        let assetConversionOperation = ClosureOperation<ChainAsset?> {
            let coderFactory = try coderFactoryWrapper.targetOperation.extractNoCancellableResultData()

            guard let chain = try chainWrapper.targetOperation.extractNoCancellableResultData() else {
                throw CrosschainAssetConversionError.unexpectedError("Chain not found")
            }

            return AssetHubTokensConverter.convertFromMultilocationToLocal(
                assetId,
                chain: chain,
                conversionClosure: AssetHubTokensConverter.createPoolAssetToLocalClosure(
                    for: chain,
                    codingFactory: coderFactory
                )
            )
        }

        assetConversionOperation.addDependency(coderFactoryWrapper.targetOperation)

        return coderFactoryWrapper
            .insertingHead(operations: chainWrapper.allOperations)
            .insertingTail(operation: assetConversionOperation)
    }
}

extension CrosschainAssetConversionFactory: CrosschainAssetConversionFactoryProtocol {
    func createConversionWrapper(
        from assetLocation: XcmV3.Multilocation
    ) -> CompoundOperationWrapper<ChainAsset?> {
        switch assetLocation.interior.items.first {
        case let .parachain(paraId):
            let assetId = XcmV3.Multilocation(
                parents: 0,
                interior: .init(items: Array(assetLocation.interior.items.dropFirst(1)))
            )
            return createAssetsPalletWrapper(for: paraId, assetId: assetId)
        case nil:
            guard let asset = baseChain.utilityChainAsset() else {
                return .createWithResult(nil)
            }

            return .createWithResult(asset)
        default:
            return .createWithResult(nil)
        }
    }
}
