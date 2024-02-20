import Foundation
@testable import novawallet

enum AccountGenerator {
    static func createWatchOnly(for accountId: AccountId, name: String = "Test") -> MetaAccountModel {
        MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: accountId,
            substrateCryptoType: MultiassetCryptoType.sr25519.rawValue,
            substratePublicKey: accountId,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            type: .watchOnly
        )
    }
    
    static func generateMetaAccount(generatingChainAccounts count: Int) -> MetaAccountModel {
        let chainAccounts = (0..<count).map { _ in generateChainAccount() }
        return generateMetaAccount(with: Set(chainAccounts))
    }

    static func generateMetaAccount(
        with chainAccounts: Set<ChainAccountModel> = [],
        type: MetaAccountModelType = .secrets
    ) -> MetaAccountModel {
        MetaAccountModel(
            metaId: UUID().uuidString,
            name: UUID().uuidString,
            substrateAccountId: Data.random(of: 32)!,
            substrateCryptoType: 0,
            substratePublicKey: Data.random(of: 32)!,
            ethereumAddress: Data.random(of: 20)!,
            ethereumPublicKey: Data.random(of: 32)!,
            chainAccounts: chainAccounts,
            type: type
        )
    }

    static func generateChainAccount() -> ChainAccountModel {
        ChainAccountModel(
            chainId: Data.random(of: 32)!.toHex(),
            accountId: Data.random(of: 32)!,
            publicKey: Data.random(of: 32)!,
            cryptoType: 0,
            proxy: nil
        )
    }
    
    static func generateProxiedChainAccount(
        for model: ProxyAccountModel
    ) -> ChainAccountModel {
        ChainAccountModel(
            chainId: Data.random(of: 32)!.toHex(),
            accountId: Data.random(of: 32)!,
            publicKey: Data.random(of: 32)!,
            cryptoType: 0,
            proxy: model
        )
    }
}
