import Foundation

class MultisigMetaAccountFactory {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }
}

private extension MultisigMetaAccountFactory {
    enum MultisigMetaAccountType {
        case singleChain(ChainAccountModel, MultisigModel)
        case universalSubstrate(AccountId, MultisigModel)
        case universamEvm(AccountId, MultisigModel)
    }
}

private extension MultisigMetaAccountFactory {
    func updateMultisigStatus(
        for metaAccount: ManagedMetaAccountModel,
        _ newStatus: MultisigModel.Status,
        multisigType: MetaAccountModel.MultisigAccountType
    ) -> ManagedMetaAccountModel {
        let newInfo: MetaAccountModel?

        switch multisigType {
        case let .singleChain(chainAccount, multisig):
            guard chainAccount.chainId == chainModel.chainId else { return metaAccount }

            newInfo = metaAccount.info.replacingMultisig(
                with: .singleChain(
                    chainAccount: chainAccount,
                    multisig: multisig.replacingStatus(newStatus)
                )
            )
        case let .universal(multisig):
            newInfo = metaAccount.info.replacingMultisig(
                with: .universal(multisig: multisig.replacingStatus(newStatus))
            )
        }

        guard let newInfo else { return metaAccount }

        return metaAccount.replacingInfo(newInfo)
    }

    func createMultisigType(
        for signatory: AccountId,
        discoveredMultisig: DiscoveredMultisig,
        localMetaAccounts: [ManagedMetaAccountModel]
    ) -> MultisigMetaAccountType? {
        let signatoryWallet = localMetaAccounts.first { wallet in
            wallet.info.chainAccounts.contains { $0.accountId == signatory } &&
                wallet.info.substrateAccountId == signatory &&
                wallet.info.ethereumAddress == signatory
        }

        guard let signatoryWallet else { return nil }

        let multisigModel = MultisigModel(
            accountId: discoveredMultisig.accountId,
            signatory: signatory,
            otherSignatories: discoveredMultisig.otherSignatories(than: signatory),
            threshold: discoveredMultisig.threshold,
            status: .new
        )

        if signatoryWallet.info.chainAccounts.isEmpty {
            if let substrateAccountId = signatoryWallet.info.substrateAccountId {
                return .universalSubstrate(substrateAccountId, multisigModel)
            } else if let ethereumAddress = signatoryWallet.info.ethereumAddress {
                return .universamEvm(ethereumAddress, multisigModel)
            } else {
                return nil
            }
        } else {
            guard let chainAccount = signatoryWallet.info.chainAccounts.first(where: {
                $0.chainId == chainModel.chainId && $0.accountId == signatory
            }) else {
                return nil
            }

            return .singleChain(chainAccount, multisigModel)
        }
    }
}

extension MultisigMetaAccountFactory: DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DelegatedAccountProtocol,
        delegatorAccountId: AccountId,
        using identities: [AccountId: AccountIdentity],
        localMetaAccounts: [ManagedMetaAccountModel]
    ) throws -> ManagedMetaAccountModel {
        guard let multisig = delegatedAccount as? DiscoveredMultisig else {
            throw DelegatedAccountError.invalidAccountType
        }

        let name = try identities[multisig.accountId]?.displayName
            ?? multisig.accountId.toAddress(using: chainModel.chainFormat)

        guard let multisigAccountType = createMultisigType(
            for: delegatorAccountId,
            discoveredMultisig: multisig,
            localMetaAccounts: localMetaAccounts
        ) else {
            throw DelegatedAccountError.invalidAccountType
        }

        return switch multisigAccountType {
        case let .universalSubstrate(accountId, multisigModel):
            ManagedMetaAccountModel(info: MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: accountId,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: .multisig,
                multisig: multisigModel
            ))
        case let .universamEvm(address, multisigModel):
            ManagedMetaAccountModel(info: MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: nil,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: address,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: .multisig,
                multisig: multisigModel
            ))
        case let .singleChain(chainAccount, multisigModel):
            ManagedMetaAccountModel(info: MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: nil,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [chainAccount.replacingMultisig(multisigModel)],
                type: .multisig,
                multisig: nil
            ))
        }
    }

    func renew(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel {
        guard
            let multisigAccountType = metaAccount.info.multisigAccount(),
            multisigAccountType.multisig.multisigAccount?.status == .revoked
        else {
            return metaAccount
        }

        return updateMultisigStatus(
            for: metaAccount,
            .new,
            multisigType: multisigAccountType
        )
    }

    func markAsRevoked(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel {
        guard let multisigType = metaAccount.info.multisigAccount() else { return metaAccount }

        return updateMultisigStatus(
            for: metaAccount,
            .revoked,
            multisigType: multisigType
        )
    }

    func matchesDelegatedAccount(
        _ metaAccount: ManagedMetaAccountModel,
        delegatedAccount: DelegatedAccountProtocol,
        delegatorAccountId: AccountId
    ) -> Bool {
        guard
            let multisig = delegatedAccount as? DiscoveredMultisig,
            let multisigAccountType = metaAccount.info.multisigAccount()
        else { return false }

        return switch multisigAccountType {
        case let .singleChain(chainAccount, multisigModel):
            chainAccount.accountId == delegatorAccountId &&
                multisigModel.accountId == multisig.accountId
        case let .universal(multisigModel):
            metaAccount.info.substrateAccountId == delegatorAccountId &&
                multisigModel.accountId == multisig.accountId
        }
    }

    func extractDelegateIdentifier(from metaAccount: ManagedMetaAccountModel) -> DelegateIdentifier? {
        guard let multisigAccountType = metaAccount.info.multisigAccount() else {
            return nil
        }

        let multisigAccountId: AccountId
        let delegatorAccountId: AccountId

        switch multisigAccountType {
        case let .singleChain(chainAccount, multisig):
            delegatorAccountId = chainAccount.accountId
            multisigAccountId = multisig.accountId
        case let .universal(multisig):
            guard let substrateAccountId = metaAccount.info.substrateAccountId else {
                return nil
            }

            delegatorAccountId = substrateAccountId
            multisigAccountId = multisig.accountId
        }

        return DelegateIdentifier(
            delegatorAccountId: delegatorAccountId,
            delegateAccountId: multisigAccountId,
            delegateType: .multisig
        )
    }

    func canHandle(_ metaAccount: ManagedMetaAccountModel) -> Bool {
        metaAccount.info.multisigAccount() != nil
    }

    func canHandle(_ delegatedAccount: any DelegatedAccountProtocol) -> Bool {
        delegatedAccount is DiscoveredMultisig
    }
}
