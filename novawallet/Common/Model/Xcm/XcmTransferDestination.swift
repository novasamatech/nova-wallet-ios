import Foundation

struct XcmTransferDestination {
    let chain: ChainModel
    let parachainId: ParaId?
    let accountId: AccountId

    func replacing(accountId: AccountId) -> XcmTransferDestination {
        XcmTransferDestination(chain: chain, parachainId: parachainId, accountId: accountId)
    }
}

struct XcmTransferDestinationId {
    let chainId: ChainModel.Id
    let accountId: AccountId
}
