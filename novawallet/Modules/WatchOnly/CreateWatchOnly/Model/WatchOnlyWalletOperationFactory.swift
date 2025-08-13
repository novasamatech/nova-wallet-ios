import Foundation
import Operation_iOS

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

            let substrateCryptoType = MultiassetCryptoType.sr25519.rawValue

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: request.name,
                substrateAccountId: substrateAccountId,
                substrateCryptoType: substrateCryptoType,
                substratePublicKey: substrateAccountId,
                ethereumAddress: evmAddress,
                ethereumPublicKey: evmAddress,
                chainAccounts: [],
                type: .watchOnly,
                multisig: nil
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

            let cryptoType = chain.isEthereumBased ? MultiassetCryptoType.ethereumEcdsa :
                MultiassetCryptoType.sr25519

            let chainAccount = ChainAccountModel(
                chainId: chain.chainId,
                accountId: accountId,
                publicKey: accountId,
                cryptoType: cryptoType.rawValue,
                proxy: nil,
                multisig: nil
            )

            return wallet.replacingChainAccount(chainAccount)
        }
    }
}
