import Foundation
import RobinHood

struct ChainAccountModel: Hashable {
    let chainId: String
    let accountId: Data
    let publicKey: Data
    let cryptoType: UInt8
    let proxieds: Set<ProxiedAccountModel>

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
