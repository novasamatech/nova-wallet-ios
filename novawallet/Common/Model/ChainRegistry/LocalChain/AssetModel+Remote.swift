import Foundation

extension AssetModel {
    // [TEMP-QA-HACK] EWT staking: inject "parachain-avn" type for EWT on EWX
    // until nova-utils upstream PR adds it to chains.json / chains_dev.json.
    // Remove this set and the priceId check once the PR lands.
    private static let ewtStakingOverrides: [PriceId: [StakingType]] = [
        "energy-web-token": [.parachainAvn]
    ]

    init(remoteModel: RemoteAssetModel, enabled: Bool) {
        assetId = remoteModel.assetId
        icon = remoteModel.icon
        name = remoteModel.name
        symbol = remoteModel.symbol
        precision = remoteModel.precision
        priceId = remoteModel.priceId
        type = remoteModel.type
        typeExtras = remoteModel.typeExtras
        buyProviders = remoteModel.buyProviders
        sellProviders = remoteModel.sellProviders
        self.enabled = enabled
        source = .remote

        // [TEMP-QA-HACK] Inject staking type for EWT if not already present in remote
        if let override = remoteModel.priceId.flatMap({ Self.ewtStakingOverrides[$0] }),
           remoteModel.staking == nil || remoteModel.staking?.isEmpty == true {
            stakings = override
        } else {
            stakings = remoteModel.staking?.map { StakingType(rawType: $0) }
        }
    }
}
