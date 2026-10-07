import Foundation

enum AssetListSubtensorBanner: Equatable {
    case earn
    case getTao

    static let bannerId = "bittensor-earn"

    static func resolveChainAsset(from chain: ChainModel?, wallet: MetaAccountModel?) -> ChainAsset? {
        guard
            let chain,
            let wallet,
            wallet.fetch(for: chain.accountRequest()) != nil,
            let chainAsset = chain.utilityChainAsset(),
            chainAsset.asset.hasSubtensorStaking else {
            return nil
        }

        return chainAsset
    }

    static func resolve(
        for chainAssetId: ChainAssetId,
        model: AssetListBuilderResult.Model
    ) -> AssetListSubtensorBanner? {
        switch model.balances[chainAssetId] {
        case let .success(balance):
            return balance.freeInPlank > 0 ? .earn : .getTao
        case .failure:
            return nil
        case .none:
            guard case .success = model.balanceResults[chainAssetId] else {
                return nil
            }

            return .getTao
        }
    }

    func createLocalBanner(for locale: Locale) -> Banners.LocalBanner {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let title: String
        let details: String

        switch self {
        case .earn:
            title = strings.stakingSubtensorBannerTitle()
            details = strings.stakingSubtensorBannerMessage()
        case .getTao:
            title = strings.stakingSubtensorBannerNoTaoTitle()
            details = strings.stakingSubtensorBannerNoTaoMessage()
        }

        return Banners.LocalBanner(
            banner: Banner(
                id: Self.bannerId,
                background: R.image.imageBittensorBannerBg(),
                image: nil,
                clipsToBounds: false,
                actionLink: nil,
                layout: .featured
            ),
            title: title,
            details: details
        )
    }
}
