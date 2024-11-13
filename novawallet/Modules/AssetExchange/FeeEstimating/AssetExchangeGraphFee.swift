import Foundation
import Operation_iOS

protocol AssetExchangeFeeSupporting {
    func canPayFee(inNonNative chainAsset: ChainAsset) -> Bool
}

protocol AssetExchangeFeeSupportFetching {
    func createFeeSupportWrapper() -> CompoundOperationWrapper<AssetExchangeFeeSupporting>
}

protocol AssetExchangeFeeSupportProviding {
    func setup()
    func throttle()

    func subscribeExchanges(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping ([AssetExchangeFeeSupportFetching]) -> Void
    )

    func unsubscribeExchanges(_ target: AnyObject)
}
