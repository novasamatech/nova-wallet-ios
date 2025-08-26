import Foundation
import Operation_iOS

protocol AssetExchangeFeeSupporting {
    func canPayFee(inNonNative chainAssetId: ChainAssetId) -> Bool
}

protocol AssetExchangeFeeSupportFetching {
    var identifier: String { get }

    func createFeeSupportWrapper() -> CompoundOperationWrapper<AssetExchangeFeeSupporting>
}

protocol AssetExchangeFeeSupportFetchersProviding {
    func setup()
    func throttle()

    func subscribeFeeFetchers(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping ([AssetExchangeFeeSupportFetching]) -> Void
    )

    func unsubscribeFeeFetchers(_ target: AnyObject)
}

protocol AssetsExchangeFeeSupportProviding {
    func setup()
    func throttle()

    func subscribeFeeSupport(
        _ target: AnyObject,
        notifyingIn queue: DispatchQueue,
        onChange: @escaping (AssetExchangeFeeSupporting?) -> Void
    )

    func unsubscribe(_ target: AnyObject)

    func fetchCurrentState(in queue: DispatchQueue, completionClosure: @escaping (AssetExchangeFeeSupporting?) -> Void)
}
