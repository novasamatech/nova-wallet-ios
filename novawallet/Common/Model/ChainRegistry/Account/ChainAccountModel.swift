import Foundation
import Operation_iOS

struct ChainAccountModel: Hashable {
    let chainId: String
    let accountId: Data
    let publicKey: Data
    let cryptoType: UInt8
    let proxy: DelegatedAccount.ProxyAccountModel?
    let multisig: DelegatedAccount.MultisigAccountModel?

    var isEthereumBased: Bool {
        cryptoType == MultiassetCryptoType.ethereumEcdsa.rawValue
    }
}

extension ChainAccountModel: Identifiable {
    var identifier: String {
        [
            chainId,
            accountId.toHex(),
            "\(cryptoType)"
        ].joined(separator: "-")
    }
}

extension ChainAccountModel {
    func replacingDelegatedAccountStatus(
        from oldStatus: DelegatedAccount.Status,
        to newStatus: DelegatedAccount.Status
    ) -> ChainAccountModel {
        if multisig != nil {
            replacingMultisigStatus(from: oldStatus, to: newStatus)
        } else if proxy != nil {
            replacingProxyStatus(from: oldStatus, to: newStatus)
        } else {
            self
        }
    }

    func replacingProxyStatus(
        from oldStatus: DelegatedAccount.Status,
        to newStatus: DelegatedAccount.Status
    ) -> ChainAccountModel {
        guard let proxy = self.proxy, proxy.status == oldStatus else {
            return self
        }

        return .init(
            chainId: chainId,
            accountId: accountId,
            publicKey: publicKey,
            cryptoType: cryptoType,
            proxy: .init(type: proxy.type, accountId: proxy.accountId, status: newStatus),
            multisig: multisig
        )
    }

    func replacingMultisigStatus(
        from oldStatus: DelegatedAccount.Status,
        to newStatus: DelegatedAccount.Status
    ) -> ChainAccountModel {
        guard let multisig, multisig.status == oldStatus else {
            return self
        }

        return .init(
            chainId: chainId,
            accountId: accountId,
            publicKey: publicKey,
            cryptoType: cryptoType,
            proxy: proxy,
            multisig: multisig.replacingStatus(newStatus)
        )
    }

    func replacingProxy(_ proxy: DelegatedAccount.ProxyAccountModel?) -> ChainAccountModel {
        .init(
            chainId: chainId,
            accountId: accountId,
            publicKey: publicKey,
            cryptoType: cryptoType,
            proxy: proxy,
            multisig: multisig
        )
    }

    func replacingMultisig(_ multisig: DelegatedAccount.MultisigAccountModel?) -> ChainAccountModel {
        .init(
            chainId: chainId,
            accountId: accountId,
            publicKey: publicKey,
            cryptoType: cryptoType,
            proxy: proxy,
            multisig: multisig
        )
    }
}
