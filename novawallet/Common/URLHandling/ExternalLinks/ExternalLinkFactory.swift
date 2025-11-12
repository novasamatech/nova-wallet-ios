import Foundation

final class ExternalLinkFactory: UniversalLinkFactoryProtocol {
    let referendumLinkFactory: ReferendumLinkFactoryProtocol
    let stakingLinkFactory: StakingLinkFactoryProtocol
    let giftLinkFactory: GiftLinkFactoryProtocol

    init(
        referendumLinkFactory: ReferendumLinkFactoryProtocol,
        stakingLinkFactory: StakingLinkFactoryProtocol,
        giftLinkFactory: GiftLinkFactoryProtocol
    ) {
        self.referendumLinkFactory = referendumLinkFactory
        self.stakingLinkFactory = stakingLinkFactory
        self.giftLinkFactory = giftLinkFactory
    }

    convenience init(baseUrl: URL) {
        self.init(
            referendumLinkFactory: ReferendumLinkFactory(baseUrl: baseUrl),
            stakingLinkFactory: StakingLinkFactory(baseUrl: baseUrl),
            giftLinkFactory: GiftLinkFactory(baseUrl: baseUrl)
        )
    }

    func createUrl(
        for chainModel: ChainModel,
        referendumId: ReferendumIdLocal,
        type: GovernanceType
    ) -> URL? {
        referendumLinkFactory.createExternalLink(
            for: chainModel,
            referendumId: referendumId,
            type: type
        )
    }

    func createUrlForStaking() -> URL? {
        stakingLinkFactory.createExternalLink()
    }

    func createUrlForGift(
        seed: String,
        chainId: ChainModel.Id,
        symbol: AssetModel.Symbol
    ) -> URL? {
        giftLinkFactory.createExternalLink(
            using: seed,
            chainId: chainId,
            symbol: symbol
        )
    }
}
