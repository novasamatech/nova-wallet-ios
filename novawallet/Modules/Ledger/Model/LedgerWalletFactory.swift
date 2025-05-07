import Foundation

struct LedgerWalletFactoryResult {
    typealias Path = (chainAccount: ChainAccountModel, path: Data)

    let wallet: MetaAccountModel
    let derivationPaths: [Path]
}

protocol LedgerWalletFactoryProtocol {
    func createWallet(from accountsStore: LedgerAccountsStore, name: String) throws -> LedgerWalletFactoryResult
}

enum LedgerWalletFactoryError: Error {
    case derivationPathNotFound(accountId: AccountId)
    case noChainAccounts
}

final class LedgerWalletFactory: LedgerWalletFactoryProtocol {
    func createWallet(from accountsStore: LedgerAccountsStore, name: String) throws -> LedgerWalletFactoryResult {
        let accountsAndPaths: [LedgerWalletFactoryResult.Path] = try accountsStore.state
            .compactMap { ledgerAccount in
                guard let info = ledgerAccount.info else {
                    return nil
                }

                let chainAccount = ChainAccountModel(
                    chainId: ledgerAccount.chain.chainId,
                    accountId: info.accountId,
                    publicKey: info.publicKey,
                    cryptoType: info.cryptoType.rawValue,
                    proxy: nil,
                    multisig: nil
                )

                guard let derivationPath = accountsStore.derivationPath(for: chainAccount.accountId) else {
                    throw LedgerWalletFactoryError.derivationPathNotFound(accountId: chainAccount.accountId)
                }

                return LedgerWalletFactoryResult.Path(chainAccount: chainAccount, path: derivationPath)
            }

        let chainAccounts = accountsAndPaths.map(\.0)

        guard !chainAccounts.isEmpty else {
            throw LedgerWalletFactoryError.noChainAccounts
        }

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: nil,
            substrateCryptoType: nil,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: Set(chainAccounts),
            type: .ledger,
            multisig: nil
        )

        return LedgerWalletFactoryResult(wallet: wallet, derivationPaths: accountsAndPaths)
    }
}
