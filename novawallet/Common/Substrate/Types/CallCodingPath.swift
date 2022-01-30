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
        [.transfer, .transferKeepAlive].contains(self)
    }

    var isAssetsTransfer: Bool {
        [.assetsTransfer, .assetsTransferKeepAlive].contains(self)
    }

    var isTokensTransfer: Bool {
        [
            .tokensTransfer,
            .currenciesTransfer,
            .tokensTransferKeepAlive,
            .currenciesTransferKeepAlive
        ].contains(self)
    }

    static var transfer: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer")
    }

    static var transferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer_keep_alive")
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

    static var assetsTransfer: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "transfer")
    }

    static var assetsTransferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "transfer_keep_alive")
    }
}
