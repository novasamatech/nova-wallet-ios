import Foundation

final class MultisigUniMetaAccountFactory {
    enum UniType {
        case substrate
        case evm
    }
}

private extension MultisigUniMetaAccountFactory {
    func ensureCanHandle(
        delegatedAccount: DiscoveredDelegatedAccountProtocol
    ) -> DiscoveredAccount.MultisigModel? {
        delegatedAccount as? DiscoveredAccount.MultisigModel
    }

    func ensureUniMultisigType(
        for multisig: DiscoveredAccount.MultisigModel,
        context: DelegatedMetaAccountFactoryContext
    ) -> UniType? {
        let signatoryWallets: [MetaAccountModel] = context.metaAccounts.compactMap { wallet in
            guard wallet.info.contains(accountId: multisig.signatory) else {
                return nil
            }

            return wallet.info
        }

        guard !signatoryWallets.isEmpty, signatoryWallets.allSupportUniversalMultisig() else {
            return nil
        }

        if signatoryWallets.allMatchSubstrateAccount(multisig.signatory) {
            return .substrate
        } else if signatoryWallets.allMatchEthereumAccount(multisig.signatory) {
            return .evm
        } else {
            return nil
        }
    }

    func createWallet(
        for multisig: DiscoveredAccount.MultisigModel,
        uniType: UniType,
        context: DelegatedMetaAccountFactoryContext
    ) -> ManagedMetaAccountModel {
        let name = context.deriveName(for: multisig.accountId, maybeChain: nil)

        let multisigModel = DelegatedAccount.MultisigAccountModel(
            accountId: multisig.accountId,
            signatory: multisig.signatory,
            otherSignatories: multisig.otherSignatories(than: multisig.signatory),
            threshold: multisig.threshold,
            status: .new
        )

        switch uniType {
        case .substrate:
            return ManagedMetaAccountModel(info: MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: multisig.accountId,
                substrateCryptoType: MultiassetCryptoType.sr25519.rawValue,
                substratePublicKey: multisig.accountId,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: .multisig,
                multisig: multisigModel
            ))
        case .evm:
            return ManagedMetaAccountModel(info: MetaAccountModel(
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
        }
    }
}

extension MultisigUniMetaAccountFactory: DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DiscoveredDelegatedAccountProtocol,
        context: DelegatedMetaAccountFactoryContext
    ) -> ManagedMetaAccountModel? {
        guard let multisigModel = ensureCanHandle(delegatedAccount: delegatedAccount) else {
            return nil
        }

        guard let uniType = ensureUniMultisigType(for: multisigModel, context: context) else {
            return nil
        }

        return createWallet(for: multisigModel, uniType: uniType, context: context)
    }
}
