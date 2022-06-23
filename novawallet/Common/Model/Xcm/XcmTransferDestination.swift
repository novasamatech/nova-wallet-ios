import Foundation

struct XcmTransferDestination {
    let chain: ChainModel
    let parachainId: ParaId?
    let accountId: AccountId
}

struct XcmTransferDestinationId {
    let chainId: ChainModel.Id
    let accountId: AccountId
}
