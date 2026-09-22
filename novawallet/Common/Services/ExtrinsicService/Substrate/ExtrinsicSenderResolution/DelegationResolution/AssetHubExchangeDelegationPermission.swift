import Foundation
import SubstrateSdk

enum AssetHubExchangeDelegationPermission {
    static func permissionPath(
        for call: AnyRuntimeCall,
        context: RuntimeJsonContext,
        supportedAssetsPallets: Set<String>
    ) throws -> CallCodingPath {
        guard call.path == UtilityPallet.batchAllPath else {
            return call.path
        }

        let batch = try call.args.map(to: UtilityPallet.Call.self, with: context.toRawContext())

        guard
            let commissioned = AssetHubCommissionTopology.commissionedCalls(
                in: batch,
                path: call.path,
                supportedAssetsPallets: supportedAssetsPallets
            ) else {
            return call.path
        }

        return commissioned.swap.path
    }
}
