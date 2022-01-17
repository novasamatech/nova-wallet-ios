import Foundation
import RobinHood

struct DAppSettings: Identifiable {
    // normaly it is dapp url's host
    let identifier: String
    let allowed: Bool
    let favorite: Bool
}
