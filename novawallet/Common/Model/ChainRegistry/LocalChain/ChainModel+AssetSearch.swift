import Foundation
import SubstrateSdk

extension ChainModel {
    func getChainAssetByPalletAssetId(
        _ json: JSON,
        palletName: String,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> ChainAsset? {
        guard let remoteAssetId = try? StatemineAssetSerializer.encode(
            assetId: json,
            palletName: palletName,
            codingFactory: codingFactory
        ) else {
            return nil
        }

        let maybeAsset = assets.first { asset in
            guard
                asset.type == AssetType.statemine.rawValue,
                let typeExtra = try? asset.typeExtras?.map(to: StatemineAssetExtras.self) else {
                return false
            }

            let localPalletName = typeExtra.palletName ?? PalletAssets.name

            return palletName == localPalletName && typeExtra.assetId == remoteAssetId
        }

        return maybeAsset.map { ChainAsset(chain: self, asset: $0) }
    }

    func getChainAssetByOrmlAssetId(
        _ json: JSON,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> ChainAsset? {
        let maybeAsset = assets.first { asset in
            guard
                asset.type == AssetType.orml.rawValue,
                let typeExtra = try? asset.typeExtras?.map(to: OrmlTokenExtras.self) else {
                return false
            }

            do {
                let encoder = codingFactory.createEncoder()
                try encoder.append(json: json, type: typeExtra.currencyIdType)
                let currencyIdScale = try encoder.encode()
                let assetCurrencyId = try Data(hexString: typeExtra.currencyIdScale)

                return currencyIdScale == assetCurrencyId
            } catch {
                return false
            }
        }

        return maybeAsset.map { ChainAsset(chain: self, asset: $0) }
    }
}
