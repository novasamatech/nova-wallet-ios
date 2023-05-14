import Foundation

struct CallCodingPath: Hashable, Codable {
    let moduleName: String
    let callName: String
}

extension CallCodingPath {
    var isSubstrateOrEvmTransfer: Bool {
        isTransfer || isERC20Transfer || isEvmNativeTransfer || isEquilibriumTransfer
    }

    var isTransfer: Bool {
        isBalancesTransfer || isAssetsTransfer || isTokensTransfer
    }

    static var substrateTransfers: [CallCodingPath] {
        [.transfer, .transferAllowDeath, .transferKeepAlive, .forceTransfer, .transferAll]
    }

    var isBalancesTransfer: Bool {
        Self.substrateTransfers.contains(self)
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

    var isRewardOrSlashTransfer: Bool {
        [.reward, .slash].contains(self)
    }

    static var transfer: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer")
    }

    static var transferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer_keep_alive")
    }

    static var transferAllowDeath: CallCodingPath {
        CallCodingPath(moduleName: "Balances", callName: "transfer_allow_death")
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

    static var ethereumTransact: CallCodingPath {
        CallCodingPath(moduleName: "Ethereum", callName: "transact")
    }
}

// MARK: Syntetic keys

extension CallCodingPath {
    static var slash: CallCodingPath {
        CallCodingPath(moduleName: "Substrate", callName: "slash")
    }

    static var reward: CallCodingPath {
        CallCodingPath(moduleName: "Substrate", callName: "reward")
    }

    var isRewardOrSlash: Bool {
        [.slash, .reward].contains(self)
    }
}

// MARK: Filter

extension CallCodingPath {
    func matches(filter: WalletHistoryFilter) -> Bool {
        if !filter.contains(.transfers), isSubstrateOrEvmTransfer {
            return false
        }

        if !filter.contains(.rewardsAndSlashes), isRewardOrSlash {
            return false
        }

        if !filter.contains(.extrinsics), !isSubstrateOrEvmTransfer, !isRewardOrSlash {
            return false
        }

        return true
    }
}
