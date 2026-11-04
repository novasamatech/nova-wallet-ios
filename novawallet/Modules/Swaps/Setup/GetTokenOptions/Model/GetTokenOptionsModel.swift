import Foundation

struct GetTokenOptionsModel {
    let availableXcmOrigins: [ChainAsset]
    let xcmTransfers: XcmTransfers?
    let receiveAccount: MetaChainAccountResponse?
    let buyOptions: [RampAction]
    let changeNowUrl: URL?
}

extension GetTokenOptionsModel {
    static var empty: GetTokenOptionsModel {
        .init(
            availableXcmOrigins: [],
            xcmTransfers: nil,
            receiveAccount: nil,
            buyOptions: [],
            changeNowUrl: nil
        )
    }
}
