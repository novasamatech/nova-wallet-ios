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
            staking: nil,
            type: AssetType.evm.rawValue,
            typeExtras: JSON.stringValue(request.contractAddress),
            buyProviders: nil,
            enabled: true,
            source: .user
        )
    }
}
