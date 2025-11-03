import Foundation
import Lottie

protocol GiftPrepareShareViewModelFactoryProtocol {
    func createViewModel(for asset: AssetModel) -> GiftPrepareViewModel?
}

final class GiftPrepareShareViewModelFactory {}

private extension GiftPrepareShareViewModelFactory {
    func createAnimation(for asset: AssetModel) -> LottieAnimation? {
        let tokenAnimationName = "\(asset.symbol)_packing"
        let fallbackAnimationName = "Default_packing"

        let animation = LottieAnimation.named(tokenAnimationName, bundle: .main)
            ?? LottieAnimation.named(fallbackAnimationName, bundle: .main)
        
        return animation
    }
}

extension GiftPrepareShareViewModelFactory: GiftPrepareShareViewModelFactoryProtocol {
    func createViewModel(for asset: AssetModel) -> GiftPrepareViewModel? {
        guard let animation = createAnimation(for: asset) else { return nil }

        return GiftPrepareViewModel(animation: animation)
    }
}
