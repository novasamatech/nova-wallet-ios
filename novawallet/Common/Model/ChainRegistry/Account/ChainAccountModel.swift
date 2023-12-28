import Foundation
import RobinHood

struct ChainAccountModel: Hashable {
    let chainId: String
    let accountId: Data
    let publicKey: Data
    let cryptoType: UInt8
    let proxy: ProxyAccountModel?

    var isEthereumBased: Bool {
        cryptoType == MultiassetCryptoType.ethereumEcdsa.rawValue
    }
}

extension ChainAccountModel: Identifiable {
    var identifier: String {
        [
            chainId,
            accountId.toHexString(),
            "\(cryptoType)"
        ].joined(separator: "-")
    }
}

extension ChainAccountModel {
    func replacingProxyStatus(from oldStatus: ProxyAccountModel.Status, to newStatus: ProxyAccountModel.Status) -> ChainAccountModel {
        guard let proxy = self.proxy, proxy.status == oldStatus else {
            return self
        }

        return .init(
            chainId: chainId,
            accountId: accountId,
            publicKey: publicKey,
            cryptoType: cryptoType,
            proxy: .init(type: proxy.type, accountId: proxy.accountId, status: newStatus)
        )
    }

    func replacingProxy(_ proxy: ProxyAccountModel?) -> ChainAccountModel {
        .init(
            chainId: chainId,
            accountId: accountId,
            publicKey: publicKey,
            cryptoType: cryptoType,
            proxy: proxy
        )
    }
}
