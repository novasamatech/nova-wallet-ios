import Foundation

final class AssetExchangePathFilter {
    typealias Edge = AnyAssetExchangeEdge

    let selectedWallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let sufficiencyProvider: AssetExchangeSufficiencyProviding
    let feeSupport: AssetExchangeFeeSupporting
    let delayedCallExecVerifier: WalletDelayedExecVerifing

    init(
        selectedWallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        sufficiencyProvider: AssetExchangeSufficiencyProviding,
        feeSupport: AssetExchangeFeeSupporting,
        delayedCallExecVerifier: WalletDelayedExecVerifing
    ) {
        self.selectedWallet = selectedWallet
        self.chainRegistry = chainRegistry
        self.sufficiencyProvider = sufficiencyProvider
        self.feeSupport = feeSupport
        self.delayedCallExecVerifier = delayedCallExecVerifier
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

        // if call execution is delayed then allow only one segmented paths
        guard !delayedCallExecVerifier.executesCallWithDelay(
            selectedWallet,
            chain: chainIn
        ) else {
            return false
        }

        let isAssetInSufficient = sufficiencyProvider.isSufficient(chainAsset: chainAssetIn)
        let isAssetOutSufficient = sufficiencyProvider.isSufficient(chainAsset: chainAssetOut)

        let anyInsufficientAsset = !isAssetInSufficient || !isAssetOutSufficient

        // reject any path with len > 1 that includes insufficient asset
        if anyInsufficientAsset {
            return false
        }

        if edge.shouldIgnoreFeeRequirement(after: predecessor) {
            return true
        }

        if edge.requiresOriginKeepAliveOnIntermediatePosition() {
            return false
        }

        let canPayFees = (chainAssetIn.isUtilityAsset || feeSupport.canPayFee(inNonNative: chainAssetIn)) &&
            edge.canPayNonNativeFeesInIntermediatePosition()

        return canPayFees
    }
}
