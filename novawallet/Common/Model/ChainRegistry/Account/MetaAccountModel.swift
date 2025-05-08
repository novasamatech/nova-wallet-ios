import Foundation
import Operation_iOS

enum MetaAccountModelType: UInt8 {
    case secrets
    case watchOnly
    case paritySigner
    case ledger
    case polkadotVault
    case proxied
    case genericLedger
    case multisig

    var canPerformOperations: Bool {
        switch self {
        case .secrets,
             .paritySigner,
             .polkadotVault,
             .ledger,
             .proxied,
             .genericLedger,
             .multisig:
            true
        case .watchOnly:
            false
        }
    }
}

extension MetaAccountModelType {
    static func getDisplayPriorities() -> [MetaAccountModelType] {
        [
            .secrets,
            .polkadotVault,
            .paritySigner,
            .ledger,
            .proxied,
            .multisig,
            .watchOnly
        ]
    }
}

struct MetaAccountModel: Equatable, Hashable {
    // swiftlint:disable:next type_name
    typealias Id = String

    let metaId: Id
    let name: String
    let substrateAccountId: Data?
    let substrateCryptoType: UInt8?
    let substratePublicKey: Data?
    let ethereumAddress: Data?
    let ethereumPublicKey: Data?
    let chainAccounts: Set<ChainAccountModel>
    let type: MetaAccountModelType
    let multisig: MultisigModel?
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
            type: type,
            multisig: multisig
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
            type: type,
            multisig: multisig
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
            type: type,
            multisig: multisig
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
            type: type,
            multisig: multisig
        )
    }

    func replacingProxy(chainId: ChainModel.Id, proxy: ProxyAccountModel) -> MetaAccountModel {
        let proxyChainAccount = chainAccounts.first {
            $0.chainId == chainId && $0.proxy != nil
        }

        return if let newProxyChainAccount = proxyChainAccount?.replacingProxy(proxy) {
            replacingChainAccount(newProxyChainAccount)
        } else {
            self
        }
    }

    func replacingMultisig(with multisigType: MultisigAccountType) -> MetaAccountModel? {
        switch multisigType {
        case let .universal(multisig):
            MetaAccountModel(
                metaId: metaId,
                name: name,
                substrateAccountId: substrateAccountId,
                substrateCryptoType: substrateCryptoType,
                substratePublicKey: substratePublicKey,
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: ethereumPublicKey,
                chainAccounts: [],
                type: type,
                multisig: multisig
            )
        case let .singleChain(chainAccount, multisig):
            replacingChainAccount(chainAccount.replacingMultisig(multisig))
        }
    }
}
