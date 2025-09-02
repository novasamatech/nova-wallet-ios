import Foundation
import Operation_iOS
import SubstrateSdk

protocol XcmTransferResolutionFactoryProtocol {
    func createResolutionWrapper(
        for originChainAssetId: ChainAssetId,
        transferDestinationId: XcmTransferDestinationId,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<XcmTransferParties>
}

final class XcmTransferResolutionFactory {
    struct ResolvedChains {
        let origin: ChainAsset
        let destination: ChainAsset
        let reserve: ChainModel
        let metadata: XcmTransferMetadata
    }

    let chainRegistry: ChainRegistryProtocol
    let paraIdOperationFactory: ParaIdOperationFactoryProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        paraIdOperationFactory: ParaIdOperationFactoryProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.paraIdOperationFactory = paraIdOperationFactory
    }

    private func resolveChains(
        for originChainAssetId: ChainAssetId,
        destinationId: XcmTransferDestinationId,
        xcmTransfers: XcmTransfers
    ) throws -> ResolvedChains {
        let originChain = try chainRegistry.getChainOrError(for: originChainAssetId.chainId)
        let originChainAsset = try originChain.chainAssetOrError(for: originChainAssetId.assetId)

        let destinationChain = try chainRegistry.getChainOrError(for: destinationId.chainId)
        let destinationChainAsset = try destinationChain.chainAssetOrError(for: destinationId.chainAssetId.assetId)

        let metadata = try xcmTransfers.getTransferMetadata(
            for: originChainAsset,
            destinationChain: destinationChain
        )

        let reserveChain = try chainRegistry.getChainOrError(for: metadata.reserve.reserveId)

        return ResolvedChains(
            origin: originChainAsset,
            destination: destinationChainAsset,
            reserve: reserveChain,
            metadata: metadata
        )
    }

    private func createParachainIdWrapper(for chain: ChainModel) -> CompoundOperationWrapper<ParaId>? {
        guard !chain.isRelaychain else {
            return nil
        }

        return paraIdOperationFactory.createParaIdOperation(for: chain.chainId)
    }

    private func createMergeOperation(
        for resolvedChains: ResolvedChains,
        transferDestinationId: XcmTransferDestinationId,
        originParaIdWrapper: CompoundOperationWrapper<ParaId>?,
        destinationParaIdWrapper: CompoundOperationWrapper<ParaId>?,
        reserveParaIdWrapper: CompoundOperationWrapper<ParaId>?
    ) -> BaseOperation<XcmTransferParties> {
        ClosureOperation<XcmTransferParties> {
            let originParaId = try originParaIdWrapper?.targetOperation.extractNoCancellableResultData()
            let destinationParaId = try destinationParaIdWrapper?.targetOperation.extractNoCancellableResultData()
            let reserveParaId = try reserveParaIdWrapper?.targetOperation.extractNoCancellableResultData()

            let origin = XcmTransferOrigin(
                chainAsset: resolvedChains.origin,
                parachainId: originParaId
            )

            let destination = XcmTransferDestination(
                chainAsset: resolvedChains.destination,
                parachainId: destinationParaId,
                accountId: transferDestinationId.accountId
            )

            let reserve = XcmTransferReserve(chain: resolvedChains.reserve, parachainId: reserveParaId)

            return XcmTransferParties(
                origin: origin,
                destination: destination,
                reserve: reserve,
                metadata: resolvedChains.metadata
            )
        }
    }
}

extension XcmTransferResolutionFactory: XcmTransferResolutionFactoryProtocol {
    func createResolutionWrapper(
        for originChainAssetId: ChainAssetId,
        transferDestinationId: XcmTransferDestinationId,
        xcmTransfers: XcmTransfers
    ) -> CompoundOperationWrapper<XcmTransferParties> {
        do {
            let resolvedChains = try resolveChains(
                for: originChainAssetId,
                destinationId: transferDestinationId,
                xcmTransfers: xcmTransfers
            )

            var dependencies: [Operation] = []

            let originParaIdWrapper = createParachainIdWrapper(for: resolvedChains.origin.chain)

            if let originParaIdWrapper {
                dependencies.append(contentsOf: originParaIdWrapper.allOperations)
            }

            let destinationParaIdWrapper = createParachainIdWrapper(for: resolvedChains.destination.chain)

            if let destinationParaIdWrapper {
                dependencies.append(contentsOf: destinationParaIdWrapper.allOperations)
            }

            let reserveParaIdWrapper: CompoundOperationWrapper<ParaId>?

            if !resolvedChains.reserve.isRelaychain {
                if resolvedChains.reserve.chainId != resolvedChains.destination.chain.chainId {
                    reserveParaIdWrapper = createParachainIdWrapper(for: resolvedChains.reserve)

                    if let reserveParaIdWrapper {
                        dependencies.append(contentsOf: reserveParaIdWrapper.allOperations)
                    }
                } else {
                    reserveParaIdWrapper = destinationParaIdWrapper
                }
            } else {
                reserveParaIdWrapper = nil
            }

            let mergeOperation = createMergeOperation(
                for: resolvedChains,
                transferDestinationId: transferDestinationId,
                originParaIdWrapper: originParaIdWrapper,
                destinationParaIdWrapper: destinationParaIdWrapper,
                reserveParaIdWrapper: reserveParaIdWrapper
            )

            dependencies.forEach { mergeOperation.addDependency($0) }

            return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)

        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
