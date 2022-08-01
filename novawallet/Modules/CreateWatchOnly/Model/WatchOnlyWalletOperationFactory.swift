import Foundation
import RobinHood

protocol WatchOnlyWalletOperationFactoryProtocol {
    func newWatchOnlyWalletOperation(for request: WatchOnlyWallet) -> BaseOperation<MetaAccountModel>
    func replaceWatchOnlyAccountOperation(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        newAddress: AccountAddress
    ) -> BaseOperation<MetaAccountModel>
}

final class WatchOnlyWalletOperationFactory: WatchOnlyWalletOperationFactoryProtocol {
    func newWatchOnlyWalletOperation(for request: WatchOnlyWallet) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let substrateAccountId = try request.substrateAddress.toAccountId()
            let evmAddress = try request.evmAddress?.toAccountId()

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: request.name,
                substrateAccountId: substrateAccountId,
                substrateCryptoType: 0,
                substratePublicKey: substrateAccountId,
                ethereumAddress: evmAddress,
                ethereumPublicKey: evmAddress,
                chainAccounts: [],
                type: .watchOnly
            )
        }
    }

    func replaceWatchOnlyAccountOperation(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        newAddress: AccountAddress
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let accountId = try newAddress.toAccountId(using: chain.chainFormat)

            let chainAccount = ChainAccountModel(
                chainId: chain.chainId,
                accountId: accountId,
                publicKey: accountId,
                cryptoType: 0
            )

            return wallet.replacingChainAccount(chainAccount)
        }
    }
}
