import Foundation

enum LedgerWalletType {
    case legacy
    case generic

    var isLegacy: Bool {
        switch self {
        case .legacy:
            return true
        case .generic:
            return false
        }
    }
}
