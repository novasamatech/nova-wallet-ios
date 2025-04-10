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
        _ assetId: AssetConversionAssetIdProtocol,
        chain: ChainModel
    ) -> AssetConversionPallet.PoolAsset {
        let junctions = assetId.items

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
                    return .undefined(.init(parents: assetId.parents, interior: .init(items: junctions)))
                }
            default:
                return .undefined(.init(parents: assetId.parents, interior: .init(items: junctions)))
            }
        } else if assetId.parents == 1, junctions.isEmpty, chain.isUtilityTokenOnRelaychain {
            return .native
        } else {
            return .foreign(.init(parents: assetId.parents, interior: .init(items: junctions)))
        }
    }

    static func convertFromMultilocationToLocal(
        _ assetId: AssetConversionAssetIdProtocol,
        chain: ChainModel,
        conversionClosure: (AssetConversionPallet.PoolAsset) -> ChainAsset?
    ) -> ChainAsset? {
        let poolAsset = convertFromMultilocation(assetId, chain: chain)

        return conversionClosure(poolAsset)
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

                let palletJunction = XcmUni.Junction.palletInstance(palletIndex)
                let generalIndexJunction = XcmUni.Junction.generalIndex(generalIndex)

                return .init(parents: 0, interior: .init(items: [palletJunction, generalIndexJunction]))
            }
        default:
            return nil
        }
    }

    static func createPoolAssetToLocalClosure(
        for chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> (AssetConversionPallet.PoolAsset) -> ChainAsset? {
        let initAssetsStore = [JSON: (AssetModel, AssetsPalletStorageInfo)]()
        let assetsPalletTokens = chain.assets.reduce(into: initAssetsStore) { store, asset in
            let optStorageInfo = try? AssetStorageInfo.extract(from: asset, codingFactory: codingFactory)
            guard case let .statemine(info) = optStorageInfo else {
                return
            }

            store[info.assetId] = (asset, info)
        }

        return { remoteAsset in
            switch remoteAsset {
            case .native:
                return chain.utilityChainAsset()
            case let .assets(pallet, index):
                guard let localToken = assetsPalletTokens[.stringValue(String(index))] else {
                    return nil
                }

                let palletName = localToken.1.palletName ?? PalletAssets.name

                guard
                    let moduleIndex = codingFactory.metadata.getModuleIndex(palletName),
                    moduleIndex == pallet else {
                    // only Assets pallet currently supported
                    return nil
                }

                return chain.asset(for: localToken.0.assetId).map { asset in
                    ChainAsset(chain: chain, asset: asset)
                }
            case let .foreign(remoteId):
                guard
                    let json = try? remoteId.toScaleCompatibleJSON(),
                    let localToken = assetsPalletTokens[json] else {
                    return nil
                }

                return chain.asset(for: localToken.0.assetId).map { asset in
                    ChainAsset(chain: chain, asset: asset)
                }
            default:
                return nil
            }
        }
    }

    static func convertToLocalAsset(
        for assetId: JSON?,
        on chain: ChainModel,
        using codingFactory: RuntimeCoderFactoryProtocol
    ) -> ChainAsset? {
        guard let remoteAssetId = try? assetId?.map(
            to: AssetConversionPallet.AssetId.self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ) else {
            return nil
        }

        return convertFromMultilocationToLocal(
            remoteAssetId,
            chain: chain,
            conversionClosure: createPoolAssetToLocalClosure(
                for: chain,
                codingFactory: codingFactory
            )
        )
    }
}
