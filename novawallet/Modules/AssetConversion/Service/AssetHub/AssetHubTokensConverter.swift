import Foundation
import SubstrateSdk
import BigInt

struct AssetHubToken {
    let assetId: ChainAssetId
    let extras: StatemineAssetExtras
}

enum AssetHubTokensConverter {
    static func convertToMultilocation(
        chainAssetId: ChainAssetId,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> AssetConversionPallet.AssetId? {
        guard
            chain.chainId == chainAssetId.chainId,
            let localAsset = chain.asset(for: chainAssetId.assetId) else {
            return nil
        }

        return convertToMultilocation(
            chainAsset: ChainAsset(chain: chain, asset: localAsset),
            codingFactory: codingFactory
        )
    }

    static func convertFromMultilocation(
        _ assetId: AssetConversionPallet.AssetId,
        chain: ChainModel
    ) -> AssetConversionPallet.PoolAsset {
        let junctions = assetId.interior.items

        if assetId.parents == 0 {
            guard !junctions.isEmpty else {
                return .native
            }

            switch junctions[0] {
            case let .palletInstance(pallet):
                if
                    junctions.count == 2,
                    case let .generalIndex(index) = junctions[1] {
                    return .assets(pallet: pallet, index: index)
                } else {
                    return .undefined(assetId)
                }
            default:
                return .undefined(assetId)
            }
        } else if assetId.parents == 1, junctions.isEmpty, chain.isUtilityTokenOnRelaychain {
            return .native
        } else {
            return .foreign(assetId)
        }
    }

    static func convertToMultilocation(
        chainAsset: ChainAsset,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> AssetConversionPallet.AssetId? {
        guard
            let storageInfo = try? AssetStorageInfo.extract(
                from: chainAsset.asset,
                codingFactory: codingFactory
            ) else {
            return nil
        }

        switch storageInfo {
        case .native:
            if chainAsset.chain.isUtilityTokenOnRelaychain {
                return .init(parents: 1, interior: .init(items: []))
            } else {
                return .init(parents: 0, interior: .init(items: []))
            }
        case let .statemine(info):
            if info.assetIdString.isHex() {
                let remoteAssetId = try? info.assetId.map(
                    to: AssetConversionPallet.AssetId.self,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )

                return remoteAssetId
            } else {
                let palletName = info.palletName ?? PalletAssets.name

                guard
                    let palletIndex = codingFactory.metadata.getModuleIndex(palletName),
                    let generalIndex = BigUInt(info.assetIdString) else {
                    return nil
                }

                let palletJunction = XcmV3.Junction.palletInstance(palletIndex)
                let generalIndexJunction = XcmV3.Junction.generalIndex(generalIndex)

                return .init(parents: 0, interior: .init(items: [palletJunction, generalIndexJunction]))
            }
        default:
            return nil
        }
    }
}
