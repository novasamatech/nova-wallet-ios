import Foundation

final class AssetExchangePathFilter {
    typealias Edge = AnyAssetExchangeEdge

    let selectedWallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let sufficiencyProvider: AssetExchangeSufficiencyProviding
    let feeSupport: AssetExchangeFeeSupporting

    init(
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        sufficiencyProvider: AssetExchangeSufficiencyProviding,
        feeSupport: AssetExchangeFeeSupporting
    ) {
        self.selectedWallet = selectedWallet
        self.chainRegistry = chainRegistry
        self.sufficiencyProvider = sufficiencyProvider
        self.feeSupport = feeSupport
    }
}

extension AssetExchangePathFilter: GraphEdgeFiltering {
    func shouldVisit(edge: Edge, predecessor: Edge?) -> Bool {
        guard
            let chainIn = chainRegistry.getChain(for: edge.origin.chainId),
            let chainAssetIn = chainIn.chainAsset(for: edge.origin.assetId),
            let chainOut = chainRegistry.getChain(for: edge.destination.chainId),
            let chainAssetOut = chainOut.chainAsset(for: edge.destination.assetId) else {
            return false
        }

        // make sure there is origin and destination accounts
        guard selectedWallet.hasAccount(in: chainIn), selectedWallet.hasAccount(in: chainOut) else {
            return false
        }

        // first segment always allowed
        guard let predecessor else {
            return true
        }

        if !sufficiencyProvider.isSufficient(chainAsset: chainAssetOut) {
            return false
        }

        // always can pay fee in utility asset
        if chainAssetIn.isUtilityAsset {
            return true
        }

        if edge.shouldIgnoreFeeRequirement(after: predecessor) {
            return true
        }

        let canPayFees = feeSupport.canPayFee(inNonNative: chainAssetIn) &&
            edge.canPayNonNativeFeesInIntermediatePosition()

        return canPayFees
    }
}
