import Foundation

extension AssetModel {
    init(remoteModel: RemoteAssetModel, enabled: Bool) {
        assetId = remoteModel.assetId
        icon = remoteModel.icon
        name = remoteModel.name
        symbol = remoteModel.symbol
        precision = remoteModel.precision
        priceId = remoteModel.priceId
        stakings = remoteModel.staking?.map { StakingType(rawType: $0) }
        type = remoteModel.type
        typeExtras = remoteModel.typeExtras
        buyProviders = remoteModel.buyProviders
        sellProviders = remoteModel.sellProviders
        self.enabled = enabled
        source = .remote
    }
}
