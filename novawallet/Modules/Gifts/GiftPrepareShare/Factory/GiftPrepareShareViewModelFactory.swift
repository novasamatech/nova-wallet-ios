import Foundation
import Lottie

protocol GiftPrepareShareViewModelFactoryProtocol {
    func createViewModel(
        for chainAsset: ChainAsset,
        gift: GiftModel,
        locale: Locale
    ) -> GiftPrepareViewModel?

    func createShareItems(
        from sharingPayload: GiftSharingPayload,
        gift: GiftModel,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> [Any]
}

final class GiftPrepareShareViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let universalLinkFactory: UniversalLinkFactoryProtocol

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        universalLinkFactory: UniversalLinkFactoryProtocol
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.universalLinkFactory = universalLinkFactory
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

        let amount = balanceViewModelFactory.amountFromValue(
            gift.amount.decimal(assetInfo: assetDisplayInfo)
        ).value(for: locale)

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

    func createShareItems(
        from sharingPayload: GiftSharingPayload,
        gift: GiftModel,
        chainAsset: ChainAsset,
        locale: Locale
    ) -> [Any] {
        let url = universalLinkFactory.createUrlForGift(
            seed: sharingPayload.seed,
            chainId: sharingPayload.chainId,
            symbol: sharingPayload.assetSymbol
        )

        guard let urlString = url?.absoluteString else { return [] }

        let amount = balanceViewModelFactory.amountFromValue(
            gift.amount.decimal(assetInfo: chainAsset.asset.displayInfo)
        ).value(for: locale)

        let image = R.image.imageShareNovaGift()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.giftShareMessage(
            amount,
            urlString
        )

        let items: [Any] = [
            image,
            message
        ]

        return items
    }
}
