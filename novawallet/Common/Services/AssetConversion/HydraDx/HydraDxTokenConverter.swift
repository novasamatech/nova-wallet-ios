import Foundation
import SubstrateSdk

extension HydraDx {
    struct LocalRemoteAssetId: Equatable, Hashable {
        let localAssetId: ChainAssetId
        let remoteAssetId: HydraDx.AssetId
    }

    struct SwapPair: Equatable, Hashable {
        let assetIn: LocalRemoteAssetId
        let assetOut: LocalRemoteAssetId
    }

    struct LocalSwapPair: Equatable, Hashable {
        let assetIn: ChainAssetId
        let assetOut: ChainAssetId
    }

    struct RemoteSwapPair: Equatable, Hashable {
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId
    }
}

enum HydraDxTokenConverterError: Error {
    case unexpectedLocalAsset(ChainAsset)
    case unexpectedRemoteAsset(HydraDx.AssetId)
}

enum HydraDxTokenConverter {
    static func convertToLocal(
        for remoteAsset: HydraDx.AssetId,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ChainAssetId {
        if remoteAsset == HydraDx.nativeAssetId {
            if let assetId = chain.utilityChainAssetId() {
                return assetId
            } else {
                throw HydraDxTokenConverterError.unexpectedRemoteAsset(remoteAsset)
            }
        }

        let optLocalAsset = chain.assets.first { asset in
            let chainAsset = ChainAsset(chain: chain, asset: asset)

            let storageInfo = try? AssetStorageInfo.extract(
                from: chainAsset.asset,
                codingFactory: codingFactory
            )

            switch storageInfo {
            case let .orml(info):
                let context = codingFactory.createRuntimeJsonContext()
                let remoteId = try? info.currencyId.map(
                    to: StringScaleMapper<HydraDx.AssetId>.self,
                    with: context.toRawContext()
                ).value

                return remoteId == remoteAsset
            default:
                return false
            }
        }

        guard let localAsset = optLocalAsset else {
            throw HydraDxTokenConverterError.unexpectedRemoteAsset(remoteAsset)
        }

        return ChainAssetId(chainId: chain.chainId, assetId: localAsset.assetId)
    }

    static func convertToRemoteLocalMapping(
        remoteAssets: Set<HydraDx.AssetId>,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> [HydraDx.AssetId: ChainAssetId] {
        let assetsMapping: [HydraDx.AssetId: ChainAssetId] = chain.assets.reduce(into: [:]) { accum, asset in
            switch AssetType(rawType: asset.type) {
            case .orml, .ormlHydrationEvm:
                if let currencyId: StringCodable<HydraDx.AssetId> = try? asset.getOrmlCurrencyId(
                    for: codingFactory
                ) {
                    accum[currencyId.wrappedValue] = ChainAssetId(
                        chainId: chain.chainId,
                        assetId: asset.assetId
                    )
                }
            case .none:
                accum[HydraDx.nativeAssetId] = ChainAssetId(
                    chainId: chain.chainId,
                    assetId: asset.assetId
                )
            case .statemine, .equilibrium, .evmAsset, .evmNative:
                return
            }
        }

        return assetsMapping.filter { remoteAssets.contains($0.key) }
    }

    static func convertToRemote(
        chainAsset: ChainAsset,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraDx.LocalRemoteAssetId {
        let storageInfo = try AssetStorageInfo.extract(
            from: chainAsset.asset,
            codingFactory: codingFactory
        )

        switch storageInfo {
        case .native:
            return .init(localAssetId: chainAsset.chainAssetId, remoteAssetId: HydraDx.nativeAssetId)
        case let .orml(info), let .ormlHydrationEvm(info):
            let context = codingFactory.createRuntimeJsonContext()
            let remoteId = try info.currencyId.map(
                to: StringScaleMapper<HydraDx.AssetId>.self,
                with: context.toRawContext()
            ).value

            return .init(localAssetId: chainAsset.chainAssetId, remoteAssetId: remoteId)
        default:
            throw HydraDxTokenConverterError.unexpectedLocalAsset(chainAsset)
        }
    }
}
