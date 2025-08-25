import Foundation

extension AssetBalance {
    init(
        hydrationCurrencyData: HydrationApi.CurrencyData,
        chainAssetId: ChainAssetId,
        accountId: AccountId
    ) {
        self.init(
            chainAssetId: chainAssetId,
            accountId: accountId,
            freeInPlank: hydrationCurrencyData.free,
            reservedInPlank: hydrationCurrencyData.reserved,
            frozenInPlank: hydrationCurrencyData.frozen,
            edCountMode: .basedOnTotal,
            transferrableMode: .regular,
            blocked: false
        )
    }
}
