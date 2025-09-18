import Foundation
import Operation_iOS

struct DAppSettings: Identifiable {
    var identifier: String {
        dAppId
    }

    // normaly it is a dapp url's host
    let dAppId: String
    let metaId: String
    let source: String?
}
