import Foundation
import Lottie

protocol GiftClaimViewModelFactoryProtocol {
    func createViewModel(
        from giftDescription: ClaimableGiftDescription,
        locale: Locale
    ) -> GiftClaimViewModel?

    func createGiftUnpackingViewModel(
        for chainAsset: ChainAsset
    ) -> LottieAnimationFrameRange?
}

final class GiftClaimViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
    }
}

// MARK: - Private

private extension GiftClaimViewModelFactory {
    func createAnimation(for asset: AssetModel) -> LottieAnimation? {
        let tokenAnimationName = "\(asset.symbol)_unpacking"
        let fallbackAnimationName = Constants.defaultAnimationName

        let animation = LottieAnimation.named(tokenAnimationName, bundle: .main)
            ?? LottieAnimation.named(fallbackAnimationName, bundle: .main)

        return animation
    }
}

// MARK: - GiftClaimViewModelFactoryProtocol

extension GiftClaimViewModelFactory: GiftClaimViewModelFactoryProtocol {
    func createViewModel(
        from giftDescription: ClaimableGiftDescription,
        locale: Locale
    ) -> GiftClaimViewModel? {
        guard let animation = createAnimation(for: giftDescription.chainAsset.asset) else {
            return nil
        }

        let animationRange = LottieAnimationFrameRange(
            startFrame: Constants.animationInitialFrame,
            endFrame: Constants.animationGiftUnpackingFrame
        )

        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable

        let assetDisplayInfo = giftDescription.chainAsset.assetDisplayInfo

        let title = localizedStrings.giftClaimTitle()

        let amount = balanceViewModelFactory.amountFromValue(
            giftDescription.amount.value.decimal(assetInfo: assetDisplayInfo)
        ).value(for: locale)

        let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(from: assetDisplayInfo)

        let actionTitle = localizedStrings.giftClaimActionTitle()

        return GiftClaimViewModel(
            title: title,
            animation: animation,
            animationFrameRange: animationRange,
            amount: amount,
            assetIcon: assetIcon,
            actionTitle: actionTitle
        )
    }

    func createGiftUnpackingViewModel(
        for chainAsset: ChainAsset
    ) -> LottieAnimationFrameRange? {
        guard let animation = createAnimation(for: chainAsset.asset) else {
            return nil
        }

        return LottieAnimationFrameRange(
            startFrame: Constants.animationGiftUnpackingFrame,
            endFrame: animation.endFrame
        )
    }
}

// MARK: - Constants

private extension GiftClaimViewModelFactory {
    enum Constants {
        static let animationInitialFrame: CGFloat = 0
        static let animationGiftUnpackingFrame: CGFloat = 180
        static let defaultAnimationName: String = "Default_unpacking"
    }
}
