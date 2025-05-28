import Foundation

final class MultisigSigningWrapper: DelegatedSigningWrapper {
    override func presentFlow(
        for data: Data,
        delegatedMetaId: MetaAccountModel.Id,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        substrateContext: ExtrinsicSigningContext.Substrate,
        completion: @escaping TransactionSigningClosure
    ) {
        uiPresenter.presentMultisigFlow(
            for: data,
            multisigAccountId: delegatedMetaId,
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
