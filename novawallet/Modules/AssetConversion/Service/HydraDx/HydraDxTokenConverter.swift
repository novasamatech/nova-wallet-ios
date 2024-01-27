import Foundation
import SubstrateSdk

extension HydraDx {
    struct LocalRemoteAssetId {
        let localAssetId: ChainAssetId
        let remoteAssetId: HydraDx.OmniPoolAssetId
    }
}

enum HydraDxTokenConverter {
    static let nativeRemoteAssetId = HydraDx.OmniPoolAssetId(0)

    static func convertToRemote(
        chainAsset: ChainAsset,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> HydraDx.LocalRemoteAssetId? {
        guard
            let storageInfo = try? AssetStorageInfo.extract(
                from: chainAsset.asset,
                codingFactory: codingFactory
            ) else {
            return nil
        }

        switch storageInfo {
        case .native:
            return .init(localAssetId: chainAsset.chainAssetId, remoteAssetId: nativeRemoteAssetId)
        case let .orml(info):
            let context = codingFactory.createRuntimeJsonContext()
            let remoteId = try info.currencyId.map(
                to: StringScaleMapper<HydraDx.OmniPoolAssetId>.self,
                with: context.toRawContext()
            ).value

            return .init(localAssetId: chainAsset.chainAssetId, remoteAssetId: remoteId)
        default:
            return nil
        }
    }
}
