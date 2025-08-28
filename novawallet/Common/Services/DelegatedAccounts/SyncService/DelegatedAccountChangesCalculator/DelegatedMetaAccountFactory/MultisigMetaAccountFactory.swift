import Foundation

final class MultisigMetaAccountFactory {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }
}

private extension MultisigMetaAccountFactory {
    func createMultisigType(
        discoveredMultisig: DiscoveredAccount.MultisigModel,
        metaAccounts: [ManagedMetaAccountModel]
    ) -> MetaAccountModel.MultisigAccountType? {
        let signatoryAccountId = discoveredMultisig.signatory

        let signatoryWallets: [MetaAccountModel] = metaAccounts.compactMap { wallet in
            guard wallet.info.fetch(for: chainModel.accountRequest())?.accountId == signatoryAccountId else {
                return nil
            }

            return wallet.info
        }

        guard !signatoryWallets.isEmpty else {
            return nil
        }

        let multisigModel = DelegatedAccount.MultisigAccountModel(
            accountId: discoveredMultisig.accountId,
            signatory: signatoryAccountId,
            otherSignatories: discoveredMultisig.otherSignatories(than: signatoryAccountId),
            threshold: discoveredMultisig.threshold,
            status: .new
        )

        if signatoryWallets.allSupportUniversalMultisig() {
            if signatoryWallets.allMatchSubstrateAccount(multisigModel.signatory) {
                return .universalSubstrate(multisigModel)
            } else if signatoryWallets.allMatchEthereumAccount(multisigModel.signatory) {
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
    ) throws -> ManagedMetaAccountModel? {
        guard
            let multisig = delegatedAccount as? DiscoveredAccount.MultisigModel
        else {
            throw DelegatedAccountError.invalidAccountType
        }

        // make sure signatory wallet already added
        guard
            let multisigAccountType = createMultisigType(
                discoveredMultisig: multisig,
                metaAccounts: metaAccounts
            ) else {
            return nil
        }

        let name = try identities[multisig.accountId]?.displayName
            ?? multisig.accountId.toAddressWithDefaultConversion()

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
        case let .universalSubstrate(localMultisig), let .universalEvm(localMultisig):
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
        case .universalEvm, .universalSubstrate:
            true
        }
    }

    func canHandle(_ delegatedAccount: any DiscoveredDelegatedAccountProtocol) -> Bool {
        delegatedAccount is DiscoveredAccount.MultisigModel &&
            delegatedAccount.usability.supports(chainId: chainModel.chainId)
    }
}
