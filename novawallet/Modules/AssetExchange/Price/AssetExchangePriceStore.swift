import Foundation

final class AssetExchangePriceStore {
    @Atomic(defaultValue: [:]) private var store: [ChainAssetId: PriceData]

    init(assetListObservable: AssetListModelObservable, updateQueue: DispatchQueue = .global()) {
        store = (try? assetListObservable.state.value.priceResult?.get()) ?? [:]

        assetListObservable.addObserver(
            with: self,
            queue: updateQueue
        ) { [weak self] _, newState in
            self?.store = (try? newState.value.priceResult?.get()) ?? [:]
        }
    }
}

extension AssetExchangePriceStore: AssetExchangePriceStoring {
    func fetchPrice(for chainAsset: ChainAsset) -> PriceData? {
        store[chainAsset.chainAssetId]
    }
}
