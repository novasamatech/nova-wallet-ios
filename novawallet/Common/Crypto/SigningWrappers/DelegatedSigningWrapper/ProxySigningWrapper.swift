import Foundation

final class ProxySigningWrapper: DelegatedSigningWrapper {
    override func presentFlow(
        for data: Data,
        delegatedMetaId _: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    ) {
        uiPresenter.presentDelegatedSigningFlow(
            for: data,
            resolution: resolution,
            substrateContext: substrateContext,
            completion: completion
        )
    }

    override func presentNotEnoughPermissionsFlow(
        for metaId: String,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        completion: @escaping TransactionSigningClosure
    ) {
        uiPresenter.presentNotEnoughProxyPermissionsFlow(
            for: metaId,
            resolution: resolution,
            completion: completion
        )
    }
}
