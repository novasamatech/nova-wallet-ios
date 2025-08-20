import Foundation

enum AssetType: String {
    case statemine
    case orml
    case evmAsset = "evm"
    case evmNative
    case equilibrium
    case ormlHydrationEvm = "orml-hydration-evm"

    init?(rawType: String?) {
        if let rawType {
            self.init(rawValue: rawType)
        } else {
            return nil
        }
    }
}

extension AssetType {
    var isOrmlCompatible: Bool {
        switch self {
        case .orml, .ormlHydrationEvm:
            return true
        default:
            return false
        }
    }
}
