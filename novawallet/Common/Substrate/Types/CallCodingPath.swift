import Foundation

struct CallCodingPath: Equatable, Codable {
    let moduleName: String
    let callName: String
}

extension CallCodingPath {
    var isTransfer: Bool {
        isBalancesTransfer || isAssetsTransfer || isTokensTransfer
    }

    var isBalancesTransfer: Bool {
        [.transfer, .transferKeepAlive, .forceTransfer, .transferAll].contains(self)
    }

    var isAssetsTransfer: Bool {
        [.assetsTransfer, .assetsTransferKeepAlive, .assetsForceTransfer, .assetsTransferAll].contains(self)
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

    static var assetsTransfer: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "transfer")
    }

    static var assetsTransferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "transfer_keep_alive")
    }

    static var assetsForceTransfer: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "force_transfer")
    }

    static var assetsTransferAll: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "transfer_all")
    }

    static var ethereumTransact: CallCodingPath {
        CallCodingPath(moduleName: "Ethereum", callName: "transact")
    }
}
