import Foundation
import Operation_iOS

protocol AssetExchangeFeeSupporting {
    func canPayFee(inNonNative chainAsset: ChainAsset) -> Bool
}

protocol AssetExchangeFeeSupportFetching {
    var identifier: String { get }

    func createFeeSupportWrapper() -> CompoundOperationWrapper<AssetExchangeFeeSupporting>
}

protocol AssetExchangeFeeSupportProviding {
    func setup()
    func throttle()

    func subscribeFeeFetchers(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping ([AssetExchangeFeeSupportFetching]) -> Void
    )

    func unsubscribeFeeFetchers(_ target: AnyObject)
}
