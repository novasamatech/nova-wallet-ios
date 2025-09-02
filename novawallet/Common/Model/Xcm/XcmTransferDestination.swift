import Foundation

struct XcmTransferDestination {
    let chainAsset: ChainAsset
    let parachainId: ParaId?
    let accountId: AccountId

    var chain: ChainModel {
        chainAsset.chain
    }

    func replacing(accountId: AccountId) -> XcmTransferDestination {
        XcmTransferDestination(
            chainAsset: chainAsset,
            parachainId: parachainId,
            accountId: accountId
        )
    }
}

struct XcmTransferDestinationId {
    let chainAssetId: ChainAssetId
    let accountId: AccountId

    var chainId: ChainModel.Id {
        chainAssetId.chainId
    }
}
