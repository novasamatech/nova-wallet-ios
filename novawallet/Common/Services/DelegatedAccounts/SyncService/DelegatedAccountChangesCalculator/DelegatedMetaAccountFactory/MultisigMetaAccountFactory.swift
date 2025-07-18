import Foundation

final class MultisigMetaAccountFactory {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }
}

private extension MultisigMetaAccountFactory {
    enum MultisigMetaAccountType {
        case singleChain(ChainAccountModel)
        case universalSubstrate(DelegatedAccount.MultisigAccountModel)
        case universalEvm(DelegatedAccount.MultisigAccountModel)
    }
}

private extension MultisigMetaAccountFactory {
    func createMultisigType(
        discoveredMultisig: DiscoveredMultisig,
        metaAccounts: [ManagedMetaAccountModel]
    ) -> MultisigMetaAccountType? {
        let signatoryAccountId = discoveredMultisig.signatory

        let signatoryWallet = metaAccounts.first { wallet in
            wallet.info.fetch(for: chainModel.accountRequest())?.accountId == signatoryAccountId
        }

        guard let signatoryWallet else {
            return nil
        }

        let multisigModel = DelegatedAccount.MultisigAccountModel(
            accountId: discoveredMultisig.accountId,
            signatory: signatoryAccountId,
            otherSignatories: discoveredMultisig.otherSignatories(than: signatoryAccountId),
            threshold: discoveredMultisig.threshold,
            status: .new
        )

        if signatoryWallet.info.chainAccounts.isEmpty {
            if signatoryWallet.info.substrateAccountId == multisigModel.signatory {
                return .universalSubstrate(multisigModel)
            } else if signatoryWallet.info.ethereumAddress == multisigModel.signatory {
                return .universalEvm(multisigModel)
            } else {
                return nil
            }
        } else {
            let cryptoType: MultiassetCryptoType = chainModel.isEthereumBased ? .ethereumEcdsa : .sr25519
            let chainAccount = ChainAccountModel(
                chainId: chainModel.chainId,
                accountId: multisigModel.accountId,
                publicKey: multisigModel.accountId,
                cryptoType: cryptoType.rawValue,
                proxy: nil,
                multisig: multisigModel
            )

            return .singleChain(chainAccount)
        }
    }
}

extension MultisigMetaAccountFactory: DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DiscoveredDelegatedAccountProtocol,
        using identities: [AccountId: AccountIdentity],
        metaAccounts: [ManagedMetaAccountModel]
    ) throws -> ManagedMetaAccountModel {
        guard
            let multisig = delegatedAccount as? DiscoveredMultisig,
            let multisigAccountType = createMultisigType(
                discoveredMultisig: multisig,
                metaAccounts: metaAccounts
            )
        else {
            throw DelegatedAccountError.invalidAccountType
        }

        let name = try identities[multisig.accountId]?.displayName
            ?? multisig.accountId.toAddress(using: chainModel.chainFormat)

        let cryptoType: MultiassetCryptoType = chainModel.isEthereumBased ? .ethereumEcdsa : .sr25519

        return switch multisigAccountType {
        case let .universalSubstrate(multisigModel):
            ManagedMetaAccountModel(info: MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: multisigModel.accountId,
                substrateCryptoType: cryptoType.rawValue,
                substratePublicKey: multisigModel.accountId,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: .multisig,
                multisig: multisigModel
            ))
        case let .universalEvm(multisigModel):
            ManagedMetaAccountModel(info: MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: nil,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: multisigModel.accountId,
                ethereumPublicKey: multisigModel.accountId,
                chainAccounts: [],
                type: .multisig,
                multisig: multisigModel
            ))
        case let .singleChain(chainAccount):
            ManagedMetaAccountModel(info: MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: nil,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [chainAccount],
                type: .multisig,
                multisig: nil
            ))
        }
    }

    func renew(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel {
        guard
            let multisigAccountType = metaAccount.info.multisigAccount,
            multisigAccountType.anyChainMultisig?.status == .revoked
        else {
            return metaAccount
        }

        let info = metaAccount.info

        return metaAccount.replacingInfo(info.replacingDelegatedAccountStatus(from: .revoked, to: .new))
    }

    func markAsRevoked(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel {
        guard
            let multisigType = metaAccount.info.multisigAccount,
            let oldStatus = multisigType.anyChainMultisig?.status
        else { return metaAccount }

        let info = metaAccount.info

        return metaAccount.replacingInfo(info.replacingDelegatedAccountStatus(from: oldStatus, to: .revoked))
    }

    func matchesDelegatedAccount(
        _ metaAccount: ManagedMetaAccountModel,
        delegatedAccount: DiscoveredDelegatedAccountProtocol
    ) -> Bool {
        guard let localMultisigAccountType = metaAccount.info.multisigAccount else { return false }

        switch localMultisigAccountType {
        case let .singleChain(chainAccount):
            guard let localMultisig = chainAccount.multisig else { return false }

            return chainAccount.chainId == chainModel.chainId &&
                delegatedAccount.delegateAccountId == localMultisig.signatory &&
                delegatedAccount.accountId == localMultisig.accountId
        case let .universal(localMultisig):
            return localMultisig.accountId == delegatedAccount.accountId &&
                localMultisig.signatory == delegatedAccount.delegateAccountId
        }
    }

    func extractDelegateIdentifier(from metaAccount: ManagedMetaAccountModel) -> DelegateIdentifier? {
        guard let multisig = metaAccount.info.getMultisig(
            for: chainModel
        ) else {
            return nil
        }

        return DelegateIdentifier(
            delegatorAccountId: multisig.accountId,
            delegateAccountId: multisig.signatory,
            delegateType: .multisig
        )
    }

    func canHandle(_ metaAccount: ManagedMetaAccountModel) -> Bool {
        guard let localMultisigAccountType = metaAccount.info.multisigAccount else { return false }

        return switch localMultisigAccountType {
        case let .singleChain(chainAccount):
            chainAccount.chainId == chainModel.chainId
        case .universal:
            true
        }
    }

    func canHandle(_ delegatedAccount: any DiscoveredDelegatedAccountProtocol) -> Bool {
        delegatedAccount is DiscoveredMultisig
    }
}
