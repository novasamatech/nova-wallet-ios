import Foundation

protocol AssetExchangePriceStoring {
    func fetchPrice(for chainAsset: ChainAsset) -> PriceData?
}

protocol AssetExchangePriceStoreProviding {
    func setup()
    func throttle()

    func subscribeFeeFetchers(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping (AssetExchangePriceStoring) -> Void
    )

    func unsubscribeFeeFetchers(_ target: AnyObject)
}
