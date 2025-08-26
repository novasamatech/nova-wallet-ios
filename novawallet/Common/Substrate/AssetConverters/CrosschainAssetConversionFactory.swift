import Foundation
import Operation_iOS

protocol CrosschainAssetConversionFactoryProtocol {
    func createConversionWrapper(
        from locatableAsset: XcmUni.VersionedLocatableAsset
    ) -> CompoundOperationWrapper<ChainAsset?>
}

enum CrosschainAssetConversionError: Error {
    case unexpectedError(String)
    case unsupportedAssetId(XcmUni.AssetId)
}

final class CrosschainAssetConversionFactory {
    let chainRegistry: ChainRegistryProtocol
    let relayChain: ChainModel
    let operationQueue: OperationQueue
    let parachainResolver: ParachainResolving

    init(
        relayChain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        parachainResolver: ParachainResolving,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.relayChain = relayChain
        self.parachainResolver = parachainResolver
        self.operationQueue = operationQueue
    }

    private func createAssetsPalletWrapper(
        for paraId: ParaId,
        assetId: XcmUni.AssetId,
        chainRegistry: ChainRegistryProtocol
    ) -> CompoundOperationWrapper<ChainAsset?> {
        let paraResolutionWrapper = parachainResolver.resolveChainId(
            by: paraId,
            relaychainId: relayChain.chainId
        )

        let chainWrapper = OperationCombiningService<ChainModel?>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            guard let chainId = try paraResolutionWrapper.targetOperation.extractNoCancellableResultData() else {
                return .createWithResult(nil)
            }

            return chainRegistry.asyncWaitChainWrapper(for: chainId)
        }

        chainWrapper.addDependency(wrapper: paraResolutionWrapper)

        let coderFactoryWrapper = OperationCombiningService<RuntimeCoderFactoryProtocol>.compoundNonOptionalWrapper(
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
                assetId.location,
                chain: chain,
                conversionClosure: AssetHubTokensConverter.createPoolAssetToLocalClosure(
                    for: chain,
                    codingFactory: coderFactory
                )
            )
        }

        assetConversionOperation.addDependency(coderFactoryWrapper.targetOperation)

        return coderFactoryWrapper
            .insertingHead(operations: paraResolutionWrapper.allOperations + chainWrapper.allOperations)
            .insertingTail(operation: assetConversionOperation)
    }
}

extension CrosschainAssetConversionFactory: CrosschainAssetConversionFactoryProtocol {
    func createConversionWrapper(
        from locatableAsset: XcmUni.VersionedLocatableAsset
    ) -> CompoundOperationWrapper<ChainAsset?> {
        let assetId = locatableAsset.entity.assetId
        let location = locatableAsset.entity.location

        // only relaychain relative resolution supported
        guard location.parents == 0 else {
            return .createWithResult(nil)
        }

        switch location.interior.items.first {
        case let .parachain(paraId):
            return createAssetsPalletWrapper(
                for: paraId,
                assetId: assetId,
                chainRegistry: chainRegistry
            )
        case nil:
            guard let asset = relayChain.utilityChainAsset() else {
                return .createWithResult(nil)
            }

            return .createWithResult(asset)
        default:
            return .createWithResult(nil)
        }
    }
}
