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
        let destination: ChainModel
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

        let metadata = try xcmTransfers.getTransferMetadata(
            for: originChainAsset,
            destinationChain: destinationChain
        )

        let reserveChain = try chainRegistry.getChainOrError(for: metadata.reserve.reserveId)

        return ResolvedChains(
            origin: originChainAsset,
            destination: destinationChain,
            reserve: reserveChain,
            metadata: metadata
        )
    }

    private func createParachainIdWrapper(for chainId: ChainModel.Id) -> CompoundOperationWrapper<ParaId> {
        paraIdOperationFactory.createParaIdOperation(for: chainId)
    }

    private func createMergeOperation(
        for resolvedChains: ResolvedChains,
        transferDestinationId: XcmTransferDestinationId,
        destinationParaIdWrapper: CompoundOperationWrapper<ParaId>?,
        reserveParaIdWrapper: CompoundOperationWrapper<ParaId>?
    ) -> BaseOperation<XcmTransferParties> {
        ClosureOperation<XcmTransferParties> {
            let destinationParaId = try destinationParaIdWrapper?.targetOperation.extractNoCancellableResultData()
            let reserveParaId = try reserveParaIdWrapper?.targetOperation.extractNoCancellableResultData()

            let destination = XcmTransferDestination(
                chain: resolvedChains.destination,
                parachainId: destinationParaId,
                accountId: transferDestinationId.accountId
            )

            let reserve = XcmTransferReserve(chain: resolvedChains.reserve, parachainId: reserveParaId)

            return XcmTransferParties(
                origin: resolvedChains.origin,
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

            let destinationParaIdWrapper: CompoundOperationWrapper<ParaId>?

            if !resolvedChains.destination.isRelaychain {
                let wrapper = createParachainIdWrapper(
                    for: resolvedChains.destination.chainId
                )

                dependencies.append(contentsOf: wrapper.allOperations)

                destinationParaIdWrapper = wrapper
            } else {
                destinationParaIdWrapper = nil
            }

            let reserveParaIdWrapper: CompoundOperationWrapper<ParaId>?

            if !resolvedChains.reserve.isRelaychain {
                if resolvedChains.reserve.chainId != resolvedChains.destination.chainId {
                    let wrapper = createParachainIdWrapper(for: resolvedChains.reserve.chainId)

                    dependencies.append(contentsOf: wrapper.allOperations)

                    reserveParaIdWrapper = wrapper
                } else {
                    reserveParaIdWrapper = destinationParaIdWrapper
                }
            } else {
                reserveParaIdWrapper = nil
            }

            let mergeOperation = createMergeOperation(
                for: resolvedChains,
                transferDestinationId: transferDestinationId,
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
