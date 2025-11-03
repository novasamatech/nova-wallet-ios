import Foundation
import Lottie

protocol GiftPrepareShareViewModelFactoryProtocol {
    func createViewModel(
        for chainAsset: ChainAsset,
        gift: GiftModel,
        locale: Locale
    ) -> GiftPrepareViewModel?
}

final class GiftPrepareShareViewModelFactory {
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
    func createViewModel(
        for chainAsset: ChainAsset,
        gift: GiftModel,
        locale: Locale
    ) -> GiftPrepareViewModel? {
        guard let animation = createAnimation(for: chainAsset.asset) else { return nil }

        let localizedStrings = R.string(preferredLanguages: locale.rLanguages).localizable

        let assetDisplayInfo = chainAsset.assetDisplayInfo

        let title = localizedStrings.giftPreparedTitle()

        let amount = balanceViewModelFactory.lockingAmountFromPrice(
            gift.amount.decimal(assetInfo: assetDisplayInfo),
            priceData: nil
        ).value(for: locale).amount

        let assetIcon = assetIconViewModelFactory.createAssetIconViewModel(from: assetDisplayInfo)

        let actionTitle = localizedStrings.giftPreparedShareActionTitle()

        return GiftPrepareViewModel(
            title: title,
            animation: animation,
            amount: amount,
            assetIcon: assetIcon,
            actionTitle: actionTitle
        )
    }
}
