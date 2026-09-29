import UIKit

struct BittensorLocalBanner: Equatable {
    enum Variant: Equatable {
        case earn(headline: Decimal?)
        case getTao
    }

    static let id = "local-bittensor-earn"

    let chainAsset: ChainAsset
    let variant: Variant
}

struct BittensorLocalBannerContent {
    let model: BittensorLocalBanner
    let banner: Banner
    let resource: BannersLocalizedResource
}

extension BittensorLocalBanner {
    static func chainAsset(for chain: ChainModel) -> ChainAsset? {
        guard
            chain.chainId == KnowChainId.bittensor,
            let asset = chain.utilityAsset(),
            asset.hasSubtensorStaking else {
            return nil
        }

        return ChainAsset(chain: chain, asset: asset)
    }

    static func isEarnActionAvailable(on chainAsset: ChainAsset, config: SubtensorEarnConfig) -> Bool {
        config.isEntryEnabled && Self.chainAsset(for: chainAsset.chain)?.chainAssetId == chainAsset.chainAssetId
    }

    static func resolve(
        connectedChain: ChainModel?,
        config: SubtensorEarnConfig?,
        hasAccount: Bool,
        balance: Result<AssetBalance?, Error>?,
        closedBanners: ClosedBanners
    ) -> BittensorLocalBanner? {
        guard
            !closedBanners.contains(id),
            let config,
            config.isEntryEnabled,
            let chainAsset = connectedChain.flatMap(Self.chainAsset(for:)) else {
            return nil
        }

        let earnBanner = BittensorLocalBanner(
            chainAsset: chainAsset,
            variant: .earn(headline: config.headlineMaxAnnualRate)
        )

        guard hasAccount else {
            return earnBanner
        }

        switch balance {
        case .none:
            return nil
        case let .success(assetBalance):
            let hasFreeTao = (assetBalance?.freeInPlank ?? 0) > 0
            return hasFreeTao ? earnBanner : BittensorLocalBanner(chainAsset: chainAsset, variant: .getTao)
        case .failure:
            return earnBanner
        }
    }
}

extension BittensorLocalBanner {
    func createTexts(for locale: Locale) -> (title: String, details: String) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        switch variant {
        case let .earn(headline):
            let rate = headline.flatMap {
                NumberFormatter.percentSingle.localizableResource().value(for: locale).stringFromDecimal($0)
            }

            let details = rate.map { strings.stakingSubtensorBannerDetailsFormat($0) }
                ?? strings.stakingSubtensorBannerDetailsNorate()

            return (strings.stakingSubtensorBannerTitle(), details)
        case .getTao:
            return (strings.stakingSubtensorBannerNotaoTitle(), strings.stakingSubtensorBannerNotaoDetails())
        }
    }

    func createContent(title: String, details: String, estimatedHeight: Float) -> BittensorLocalBannerContent {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let background = renderer.image { context in
            UIColor.black.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        let banner = Banner(
            id: Self.id,
            background: background,
            image: R.image.bittensorBannerArt(),
            clipsToBounds: true,
            actionLink: nil
        )

        let resource = BannersLocalizedResource(
            bannerId: Self.id,
            title: title,
            details: details,
            estimatedHeight: estimatedHeight
        )

        return BittensorLocalBannerContent(model: self, banner: banner, resource: resource)
    }
}
