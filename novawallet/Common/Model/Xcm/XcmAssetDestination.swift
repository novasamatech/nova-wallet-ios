import Foundation

struct XcmAssetDestination {
    let chain: ChainModel
    let parachainId: ParaId?
    let accountId: AccountId
}

struct XcmAssetDestinationId {
    let chainId: ChainModel.Id
    let accountId: AccountId
}
