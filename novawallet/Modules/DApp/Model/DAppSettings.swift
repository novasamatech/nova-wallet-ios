import Foundation
import Operation_iOS

struct DAppSettings: Identifiable {
    // normaly it is a dapp url's host
    let identifier: String
    let metaId: String?
    let source: String?
}
