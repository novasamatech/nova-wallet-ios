import Foundation

struct GetTokenOptionsModel {
    let availableXcmOrigins: Set<ChainAssetId>
    let receiveAccount: MetaChainAccountResponse?
    let buyOptions: [PurchaseAction]
}

extension GetTokenOptionsModel {
    static var empty: GetTokenOptionsModel {
        .init(
            availableXcmOrigins: [],
            receiveAccount: nil,
            buyOptions: []
        )
    }
}
