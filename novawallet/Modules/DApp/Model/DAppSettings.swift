import Foundation
import RobinHood

struct DAppSettings: Identifiable {
    // normaly it is a dapp url's host
    let identifier: String
    let allowed: Bool
}

extension DAppSettings {
    func byReplacingAuthrization(_ newValue: Bool) -> DAppSettings {
        DAppSettings(identifier: identifier, allowed: newValue)
    }
}
