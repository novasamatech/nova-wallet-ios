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
            let assetIn = chainIn.asset(for: edge.origin.assetId),
            let chainOut = chainRegistry.getChain(for: edge.destination.chainId),
            let assetOut = chainOut.asset(for: edge.destination.assetId) else {
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

        let delayedCallExec = delayedCallExecVerifier.executesCallWithDelay(
            selectedWallet,
            chain: chainIn
        )

        // if call execution is delayed then allow only one segmented paths
        guard !delayedCallExec || edge.shouldIgnoreDelayedCallRequirement(after: predecessor) else {
            return false
        }

        let isAssetInSufficient = sufficiencyProvider.isSufficient(asset: assetIn)
        let isAssetOutSufficient = sufficiencyProvider.isSufficient(asset: assetOut)

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

        let canPayFees = (assetIn.isUtility || feeSupport.canPayFee(inNonNative: edge.origin)) &&
            edge.canPayNonNativeFeesInIntermediatePosition()

        return canPayFees
    }
}
