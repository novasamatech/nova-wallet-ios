import Foundation
import RobinHood

enum MetaAccountModelType: UInt8 {
    case secrets
    case watchOnly
    case paritySigner
    case ledger

    var canPerformOperations: Bool {
        switch self {
        case .secrets, .paritySigner, .ledger:
            return true
        case .watchOnly:
            return false
        }
    }
}

struct MetaAccountModel: Equatable {
    let metaId: String
    let name: String
    let substrateAccountId: Data?
    let substrateCryptoType: UInt8?
    let substratePublicKey: Data?
    let ethereumAddress: Data?
    let ethereumPublicKey: Data?
    let chainAccounts: Set<ChainAccountModel>
    let type: MetaAccountModelType
}

extension MetaAccountModel: Identifiable {
    var identifier: String { metaId }
}

extension MetaAccountModel {
    func replacingChainAccount(_ newChainAccount: ChainAccountModel) -> MetaAccountModel {
        var newChainAccounts = chainAccounts.filter {
            $0.chainId != newChainAccount.chainId
        }

        newChainAccounts.insert(newChainAccount)

        return MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: newChainAccounts,
            type: type
        )
    }

    func replacingEthereumAddress(_ newEthereumAddress: Data?) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: newEthereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            type: type
        )
    }

    func replacingEthereumPublicKey(_ newEthereumPublicKey: Data?) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: newEthereumPublicKey,
            chainAccounts: chainAccounts,
            type: type
        )
    }

    func replacingName(with newName: String) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: newName,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            type: type
        )
    }
}
