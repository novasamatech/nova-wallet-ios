import Foundation

final class MultisigSingleChainAccountFactory {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }
}

private extension MultisigSingleChainAccountFactory {
    func ensureCanHandle(
        delegatedAccount: DiscoveredDelegatedAccountProtocol
    ) -> DiscoveredAccount.MultisigModel? {
        delegatedAccount as? DiscoveredAccount.MultisigModel
    }

    func ensureChainMatchingMultisig(
        for multisig: DiscoveredAccount.MultisigModel,
        context: DelegatedMetaAccountFactoryContext
    ) -> Bool {
        let request = chainModel.accountRequest()

        let signatoryWallets: [MetaAccountModel] = context.metaAccounts.compactMap { wallet in
            guard wallet.info.fetch(for: request)?.accountId == multisig.signatory else {
                return nil
            }

            return wallet.info
        }

        // create single chain multisig if no wallet that supports universal multisig

        return !signatoryWallets.isEmpty && !signatoryWallets.containsWalletForUniMultisig()
    }

    func createWallet(
        multisig: DiscoveredAccount.MultisigModel,
        context: DelegatedMetaAccountFactoryContext
    ) -> ManagedMetaAccountModel {
        let multisigModel = DelegatedAccount.MultisigAccountModel(
            accountId: multisig.accountId,
            signatory: multisig.signatory,
            otherSignatories: multisig.otherSignatories(than: multisig.signatory),
            threshold: multisig.threshold,
            status: .new
        )

        let cryptoType: MultiassetCryptoType = chainModel.isEthereumBased ? .ethereumEcdsa : .sr25519
        let chainAccount = ChainAccountModel(
            chainId: chainModel.chainId,
            accountId: multisigModel.accountId,
            publicKey: multisigModel.accountId,
            cryptoType: cryptoType.rawValue,
            proxy: nil,
            multisig: multisigModel
        )

        let name = context.deriveName(for: multisig.accountId, maybeChain: chainModel)

        return ManagedMetaAccountModel(info: MetaAccountModel(
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

extension MultisigSingleChainAccountFactory: DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DiscoveredDelegatedAccountProtocol,
        context: DelegatedMetaAccountFactoryContext
    ) -> ManagedMetaAccountModel? {
        guard let multisig = ensureCanHandle(delegatedAccount: delegatedAccount) else {
            return nil
        }

        guard ensureChainMatchingMultisig(for: multisig, context: context) else {
            return nil
        }

        return createWallet(multisig: multisig, context: context)
    }
}
