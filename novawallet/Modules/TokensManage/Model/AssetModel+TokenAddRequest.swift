import Foundation
import SubstrateSdk

extension AssetModel {
    init?(request: EvmTokenAddRequest, priceId: String?) {
        guard let assetId = AssetModel.createAssetId(from: request.contractAddress) else {
            return nil
        }

        self.init(
            assetId: assetId,
            icon: nil,
            name: request.name,
            symbol: request.symbol,
            precision: UInt16(request.decimals),
            priceId: priceId,
            stakings: nil,
            type: AssetType.evmAsset.rawValue,
            typeExtras: AssetTypeExtras.createFrom(evmContractAddress: request.contractAddress),
            buyProviders: nil,
            sellProviders: nil,
            displayPriority: nil,
            enabled: true,
            source: .user
        )
    }
}
