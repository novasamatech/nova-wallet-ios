import Foundation
import Operation_iOS

final class CrosschainExchangeOperationPrototype: AssetExchangeBaseOperationPrototype {
    let host: CrosschainExchangeHostProtocol

    init(assetIn: ChainAsset, assetOut: ChainAsset, host: CrosschainExchangeHostProtocol) {
        self.host = host

        super.init(assetIn: assetIn, assetOut: assetOut)
    }

    private func createXcmPartiesResolutionWrapper(
        for destinationAccount: ChainAccountResponse
    ) -> CompoundOperationWrapper<XcmTransferParties> {
        host.resolutionFactory.createResolutionWrapper(
            for: assetIn.chainAssetId,
            transferDestinationId: .init(
                chainId: assetOut.chain.chainId,
                accountId: destinationAccount.accountId
            ),
            xcmTransfers: host.xcmTransfers
        )
    }
}

extension CrosschainExchangeOperationPrototype: AssetExchangeOperationPrototypeProtocol {
    var estimatedCostInUsdt: Decimal {
        // TODO: Define cost
        0
    }

    func estimatedExecutionTimeWrapper() -> CompoundOperationWrapper<TimeInterval> {
        guard let destinationAccount = host.wallet.fetch(for: assetOut.chain.accountRequest()) else {
            return .createWithError(ChainAccountFetchingError.accountNotExists)
        }

        let resolutionWrapper = createXcmPartiesResolutionWrapper(for: destinationAccount)

        let estimationTimeWrapper = OperationCombiningService<TimeInterval>.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let partiesResolution = try resolutionWrapper.targetOperation.extractNoCancellableResultData()

            let originChain = partiesResolution.origin.chain
            let destinationChain = partiesResolution.destination.chain
            let reserveChain = partiesResolution.reserve.chain

            let relaychainId = [originChain, destinationChain, reserveChain]
                .compactMap(\.parentId)
                .first ?? originChain.chainId

            var participatingChains: [ChainModel.Id] = [originChain.chainId]

            if originChain.chainId != reserveChain.chainId {
                participatingChains.append(reserveChain.chainId)

                if !originChain.isRelaychain, !reserveChain.isRelaychain {
                    participatingChains.append(relaychainId)
                }
            }

            if reserveChain.chainId != destinationChain.chainId {
                participatingChains.append(destinationChain.chainId)

                if !reserveChain.isRelaychain, !destinationChain.isRelaychain {
                    participatingChains.append(relaychainId)
                }
            }

            guard !participatingChains.isEmpty else {
                return .createWithResult(0)
            }

            return self.host.executionTimeEstimator.totalTimeWrapper(for: participatingChains)
        }

        estimationTimeWrapper.addDependency(wrapper: resolutionWrapper)

        return estimationTimeWrapper.insertingHead(operations: resolutionWrapper.allOperations)
    }
}
