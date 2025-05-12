import Foundation

class MultisigMetaAccountFactory {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }
}

extension MultisigMetaAccountFactory: DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DelegatedAccountProtocol,
        delegatorAccountId: AccountId,
        using identities: [AccountId: AccountIdentity]
    ) throws -> ManagedMetaAccountModel {
        guard let multisig = delegatedAccount as? DiscoveredMultisig else {
            throw DelegatedAccountError.invalidAccountType
        }

        let cryptoType: MultiassetCryptoType = !chainModel.isEthereumBased ? .sr25519 : .ethereumEcdsa

        let multisigModel = MultisigModel(
            accountId: multisig.accountId,
            signatory: delegatorAccountId,
            otherSignatories: multisig.otherSignatories(than: delegatorAccountId),
            threshold: multisig.threshold,
            status: .new
        )

        let chainAccountModel = ChainAccountModel(
            chainId: chainModel.chainId,
            accountId: delegatorAccountId,
            publicKey: delegatorAccountId,
            cryptoType: cryptoType.rawValue,
            proxy: nil,
            multisig: multisigModel
        )

        let name = try identities[multisig.accountId]?.displayName
            ?? multisig.accountId.toAddress(using: chainModel.chainFormat)

        let newWallet = ManagedMetaAccountModel(info: MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: nil,
            substrateCryptoType: nil,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [chainAccountModel],
            type: .multisig,
            multisig: nil
        ))

        return newWallet
    }

    func updateMetaAccount(
        _ metaAccount: ManagedMetaAccountModel,
        for _: DelegatedAccountProtocol,
        delegatorAccountId: AccountId
    ) -> ManagedMetaAccountModel {
        guard let multisigAccountType = metaAccount.info.multisigAccount() else {
            return metaAccount
        }

        let newInfo: MetaAccountModel?

        switch multisigAccountType {
        case let .singleChain(chainAccount, multisig):
            guard
                chainAccount.chainId == chainModel.chainId,
                chainAccount.accountId == delegatorAccountId
            else { return metaAccount }

            newInfo = metaAccount.info.replacingMultisig(
                with: .singleChain(
                    chainAccount: chainAccount,
                    multisig: multisig.replacingStatus(.pending)
                )
            )
        case let .universal(multisig):
            newInfo = metaAccount.info.replacingMultisig(
                with: .universal(multisig: multisig.replacingStatus(.pending))
            )
        }

        guard let newInfo else { return metaAccount }

        return metaAccount.replacingInfo(newInfo)
    }

    func markAsRevoked(
        _ metaAccount: ManagedMetaAccountModel,
        delegatorAccountId _: AccountId
    ) -> ManagedMetaAccountModel {
        // For multisigs, we typically remove them entirely instead of marking as revoked
        metaAccount
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

    func canHandle(metaAccount: ManagedMetaAccountModel) -> Bool {
        metaAccount.info.multisigAccount() != nil
    }
}
