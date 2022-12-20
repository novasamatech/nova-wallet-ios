import Foundation

struct CallCodingPath: Equatable, Codable {
    let moduleName: String
    let callName: String
}

extension CallCodingPath {
    var isSubstrateOrEvmTransfer: Bool {
        isTransfer || isERC20Transfer
    }

    var isTransfer: Bool {
        isBalancesTransfer || isAssetsTransfer || isTokensTransfer
    }

    var isBalancesTransfer: Bool {
        [.transfer, .transferKeepAlive, .forceTransfer, .transferAll].contains(self)
    }

    var isAssetsTransfer: Bool {
        [
            .assetsTransfer(for: nil),
            .assetsTransferKeepAlive(for: nil),
            .assetsForceTransfer(for: nil),
            .assetsTransferAll(for: nil),
            .localAssetsTransfer,
            .localAssetsTransferKeepAlive,
            .localAssetsForceTransfer,
            .localAssetsTransferAll
        ].contains(self)
    }

    var isTokensTransfer: Bool {
        [
            .tokensTransfer,
            .currenciesTransfer,
            .tokensTransferKeepAlive,
            .currenciesTransferKeepAlive,
            .tokensForceTransfer,
            .currenciesForceTransfer,
            .tokensTransferAll,
            .currenciesTransferAll
        ].contains(self)
    }

    static var transfers: [CallCodingPath] {
        [.transfer,
         .transferKeepAlive,
         .forceTransfer,
         .transferAll,
         .assetsTransfer(for: nil),
         .assetsTransferKeepAlive(for: nil),
         .assetsForceTransfer(for: nil),
         .assetsTransferAll(for: nil),
         .localAssetsTransfer,
         .localAssetsTransferKeepAlive,
         .localAssetsForceTransfer,
         .localAssetsTransferAll,
         .tokensTransfer,
         .currenciesTransfer,
         .tokensTransferKeepAlive,
         .currenciesTransferKeepAlive,
         .tokensForceTransfer,
         .currenciesForceTransfer,
         .tokensTransferAll,
         .currenciesTransferAll]
    }

    var isRewardOrSlashTransfer: Bool {
        [.reward, .slash].contains(self)
    }

    static var transfer: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer")
    }

    static var transferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer_keep_alive")
    }

    static var forceTransfer: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "force_transfer")
    }

    static var transferAll: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer_all")
    }

    static var tokensTransfer: CallCodingPath {
        CallCodingPath(moduleName: "Tokens", callName: "transfer")
    }

    static var currenciesTransfer: CallCodingPath {
        CallCodingPath(moduleName: "Currencies", callName: "transfer")
    }

    static var tokensTransferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Tokens", callName: "transfer_keep_alive")
    }

    static var currenciesTransferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Currencies", callName: "transfer_keep_alive")
    }

    static var tokensForceTransfer: CallCodingPath {
        CallCodingPath(moduleName: "Tokens", callName: "force_transfer")
    }

    static var currenciesForceTransfer: CallCodingPath {
        CallCodingPath(moduleName: "Currencies", callName: "force_transfer")
    }

    static var tokensTransferAll: CallCodingPath {
        CallCodingPath(moduleName: "Tokens", callName: "transfer_all")
    }

    static var currenciesTransferAll: CallCodingPath {
        CallCodingPath(moduleName: "Currencies", callName: "transfer_all")
    }

    static func assetsTransfer(for palletName: String?) -> CallCodingPath {
        CallCodingPath(moduleName: palletName ?? "Assets", callName: "transfer")
    }

    static func assetsTransferKeepAlive(for palletName: String?) -> CallCodingPath {
        CallCodingPath(moduleName: palletName ?? "Assets", callName: "transfer_keep_alive")
    }

    static func assetsForceTransfer(for palletName: String?) -> CallCodingPath {
        CallCodingPath(moduleName: palletName ?? "Assets", callName: "force_transfer")
    }

    static func assetsTransferAll(for palletName: String?) -> CallCodingPath {
        CallCodingPath(moduleName: palletName ?? "Assets", callName: "transfer_all")
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

// MARK: Syntetic keys

extension CallCodingPath {
    static var ethereumTransact: CallCodingPath {
        CallCodingPath(moduleName: "Ethereum", callName: "transact")
    }

    static var slash: CallCodingPath {
        CallCodingPath(moduleName: "Substrate", callName: "slash")
    }

    static var reward: CallCodingPath {
        CallCodingPath(moduleName: "Substrate", callName: "reward")
    }
}
