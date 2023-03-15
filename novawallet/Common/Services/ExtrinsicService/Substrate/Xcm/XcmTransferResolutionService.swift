import Foundation
import RobinHood
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
        guard
            let originChain = chainRegistry.getChain(for: originChainAssetId.chainId),
            let originAsset = originChain.asset(for: originChainAssetId.assetId) else {
            throw ChainRegistryError.noChain(originChainAssetId.chainId)
        }

        let originChainAsset = ChainAsset(chain: originChain, asset: originAsset)

        guard let destinationChain = chainRegistry.getChain(for: destinationId.chainId) else {
            throw ChainRegistryError.noChain(destinationId.chainId)
        }

        guard let reserveId = xcmTransfers.getReserveTransfering(
            from: originChainAssetId.chainId,
            assetId: originChainAssetId.assetId
        ) else {
            throw XcmTransferFactoryError.noReserve(originChainAssetId)
        }

        guard let reserveChain = chainRegistry.getChain(for: reserveId) else {
            throw ChainRegistryError.noChain(reserveId)
        }

        return ResolvedChains(origin: originChainAsset, destination: destinationChain, reserve: reserveChain)
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

            return XcmTransferParties(origin: resolvedChains.origin, destination: destination, reserve: reserve)
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
