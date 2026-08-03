import Foundation

extension PalletAssets {
    static func issuedPath(for moduleName: String?) -> EventCodingPath {
        EventCodingPath(moduleName: moduleName ?? PalletAssets.name, eventName: "Issued")
    }

    static func depositedPath(for moduleName: String?) -> EventCodingPath {
        EventCodingPath(moduleName: moduleName ?? PalletAssets.name, eventName: "Deposited")
    }
}
