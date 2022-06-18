import Foundation

struct XcmAssetDestination {
    let chain: ChainModel
    let parachainId: ParaId?
    let accountId: AccountId
}
