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

    var isDelegated: Bool {
        self == .proxied || self == .multisig
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
    let multisig: DelegatedAccount.MultisigAccountModel?
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

    func replacingProxy(
        chainId: ChainModel.Id,
        proxy: DelegatedAccount.ProxyAccountModel
    ) -> MetaAccountModel {
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
        case let .universalSubstrate(multisig), let .universalEvm(multisig):
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
        case let .singleChain(chainAccount):
            replacingChainAccount(chainAccount.replacingMultisig(multisig))
        }
    }

    func replacingDelegatedAccountStatus(
        from oldStatus: DelegatedAccount.Status,
        to newStatus: DelegatedAccount.Status
    ) -> MetaAccountModel {
        guard type == .multisig || type == .proxied else {
            return self
        }

        return if multisig != nil {
            replacingUniversalMultisigStatus(from: oldStatus, to: newStatus)
        } else {
            replacingDelegatedChainAccountStatus(from: oldStatus, to: newStatus)
        }
    }
}

private extension MetaAccountModel {
    func replacingUniversalMultisigStatus(
        from oldStatus: DelegatedAccount.Status,
        to newStatus: DelegatedAccount.Status
    ) -> MetaAccountModel {
        guard multisig?.status == oldStatus else { return self }

        return MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            type: type,
            multisig: multisig?.replacingStatus(newStatus)
        )
    }

    func replacingDelegatedChainAccountStatus(
        from oldStatus: DelegatedAccount.Status,
        to newStatus: DelegatedAccount.Status
    ) -> MetaAccountModel {
        let updatedChainAccounts = chainAccounts.map { delegatorAccount in
            let status = delegatorAccount.proxy?.status ?? delegatorAccount.multisig?.status

            guard status == oldStatus else { return delegatorAccount }

            return delegatorAccount.replacingDelegatedAccountStatus(
                from: oldStatus,
                to: newStatus
            )
        }

        return MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: Set(updatedChainAccounts),
            type: type,
            multisig: multisig
        )
    }
}
