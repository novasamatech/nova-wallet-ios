import Foundation

enum PromotionViewModelFactory {
    static func createPolkadotStakingPromotion(for locale: Locale) -> PromotionBannerView.ViewModel {
        .init(
            background: R.image.imagePolkadotStakingBg()!,
            title: R.string.localizable.polkadotStakingPromotionTitle(preferredLanguages: locale.rLanguages),
            details: R.string.localizable.polkadotStakingPromotionMessage(preferredLanguages: locale.rLanguages),
            icon: R.image.imagePolkadotStakingPromo()!
        )
    }
}
