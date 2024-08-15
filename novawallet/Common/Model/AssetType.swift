import Foundation

enum AssetType: String {
    case statemine
    case orml
    case evmAsset = "evm"
    case evmNative
    case equilibrium

    init?(rawType: String?) {
        if let rawType {
            self.init(rawValue: rawType)
        } else {
            return nil
        }
    }
}
