import Foundation
import Lottie

struct GiftClaimViewModel {
    let title: String
    let animation: LottieAnimation
    let animationFrameRange: LottieAnimationFrameRange
    let amount: String
    let assetIcon: ImageViewModelProtocol
    let controlsViewModel: ControlsViewModel
}

extension GiftClaimViewModel {
    struct ControlsViewModel {
        let claimActionViewModel: ClaimActionViewModel?
        let selectedWalletViewModel: WalletViewModel
    }

    enum ClaimActionViewModel {
        case enabled(title: String)
        case disabled(title: String)
    }

    struct WalletViewModel {
        let walletViewModel: WalletView.ViewModel
        let showAccessory: Bool
    }
}

struct LottieAnimationFrameRange {
    let startFrame: CGFloat
    let endFrame: CGFloat
}
