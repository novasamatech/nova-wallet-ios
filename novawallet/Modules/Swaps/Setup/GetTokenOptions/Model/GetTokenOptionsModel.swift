import Foundation

struct GetTokenOptionsModel {
    let availableXcmOrigins: [ChainAsset]
    let xcmTransfers: XcmTransfers?
    let receiveAccount: MetaChainAccountResponse?
    let buyOptions: [PurchaseAction]
}

extension GetTokenOptionsModel {
    static var empty: GetTokenOptionsModel {
        .init(
            availableXcmOrigins: [],
            xcmTransfers: nil,
            receiveAccount: nil,
            buyOptions: []
        )
    }
}
