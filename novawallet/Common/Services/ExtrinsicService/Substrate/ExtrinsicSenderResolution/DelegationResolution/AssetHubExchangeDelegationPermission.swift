import Foundation
import SubstrateSdk

enum AssetHubExchangeDelegationPermission {
    static func permissionPath(
        for call: AnyRuntimeCall,
        context: RuntimeJsonContext,
        supportedAssetsPallets: Set<String> = Set(PalletAssets.knownPalletNames)
    ) throws -> CallCodingPath {
        guard call.path == UtilityPallet.batchAllPath else {
            return call.path
        }

        let batch = try call.args.map(to: UtilityPallet.Call.self, with: context.toRawContext())

        guard
            batch.calls.count == 2,
            AssetConversionPallet.isSwap(batch.calls[0].path),
            isCommissionTransfer(batch.calls[1].path, supportedAssetsPallets: supportedAssetsPallets) else {
            return call.path
        }

        return batch.calls[0].path
    }

    static func isCommissionTransfer(_ path: CallCodingPath, supportedAssetsPallets: Set<String>) -> Bool {
        let supportedPaths = [CallCodingPath.transferKeepAlive] + supportedAssetsPallets.map {
            PalletAssets.assetsTransferKeepAlive(for: $0)
        }

        return supportedPaths.contains(path)
    }
}
