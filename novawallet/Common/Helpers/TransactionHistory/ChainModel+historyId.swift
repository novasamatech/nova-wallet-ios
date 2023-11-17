extension ChainModel {
    func asset(byHistoryAssetId assetId: String?) -> AssetModel? {
        guard let assetId = assetId else {
            return nil
        }
        return assets.first { asset in
            let assetMapper = CustomAssetMapper(type: asset.type, typeExtras: asset.typeExtras)
            let historyAssetId = try? assetMapper.historyAssetId()
            return historyAssetId == assetId
        }
    }
}
