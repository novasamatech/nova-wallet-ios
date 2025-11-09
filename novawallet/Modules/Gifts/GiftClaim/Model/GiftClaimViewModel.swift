import Foundation
import Lottie

struct GiftClaimViewModel {
    let title: String
    let animation: LottieAnimation
    let animationFrameRange: LottieAnimationFrameRange
    let amount: String
    let assetIcon: ImageViewModelProtocol
    let actionTitle: String
}

struct LottieAnimationFrameRange {
    let startFrame: CGFloat
    let endFrame: CGFloat
}
