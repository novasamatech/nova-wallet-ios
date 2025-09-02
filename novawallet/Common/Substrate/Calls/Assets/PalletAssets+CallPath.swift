import Foundation

extension PalletAssets {
    static let knownPalletNames: [String] = [
        PalletAssets.name,
        "LocalAssets",
        "ForeignAssets"
    ]

    static func assetsTransfer(for palletName: String?) -> CallCodingPath {
        CallCodingPath(moduleName: palletName ?? PalletAssets.name, callName: "transfer")
    }

    static func assetsTransferKeepAlive(for palletName: String?) -> CallCodingPath {
        CallCodingPath(moduleName: palletName ?? PalletAssets.name, callName: "transfer_keep_alive")
    }

    static func assetsForceTransfer(for palletName: String?) -> CallCodingPath {
        CallCodingPath(moduleName: palletName ?? PalletAssets.name, callName: "force_transfer")
    }

    static func assetsTransferAll(for palletName: String?) -> CallCodingPath {
        CallCodingPath(moduleName: palletName ?? PalletAssets.name, callName: "transfer_all")
    }

    static func possibleTransferCallPaths() -> [CallCodingPath] {
        knownPalletNames.map { palletName in
            [
                assetsTransfer(for: palletName),
                assetsTransferKeepAlive(for: palletName),
                assetsForceTransfer(for: palletName),
                assetsTransferAll(for: palletName)
            ]
        }.flatMap { $0 }
    }

    static var localAssetsTransfer: CallCodingPath {
        CallCodingPath(moduleName: "LocalAssets", callName: "transfer")
    }

    static var localAssetsTransferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "LocalAssets", callName: "transfer_keep_alive")
    }

    static var localAssetsForceTransfer: CallCodingPath {
        CallCodingPath(moduleName: "LocalAssets", callName: "force_transfer")
    }

    static var localAssetsTransferAll: CallCodingPath {
        CallCodingPath(moduleName: "LocalAssets", callName: "transfer_all")
    }
}
