import Foundation

struct HydraAccountAsset: Equatable, Hashable {
    let accountId: AccountId
    let assetId: HydraDx.AssetId
}
