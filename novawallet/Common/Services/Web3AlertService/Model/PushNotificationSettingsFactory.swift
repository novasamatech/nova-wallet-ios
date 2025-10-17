import SubstrateSdk
import Foundation

protocol PushNotificationSettingsFactoryProtocol {
    func createWalletSettings(
        for wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> Web3Alert.LocalSettings

    func createWallet(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> Web3Alert.LocalWallet
}

final class PushNotificationSettingsFactory: PushNotificationSettingsFactoryProtocol {
    func createWalletSettings(
        for wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> Web3Alert.LocalSettings {
        let web3Wallet = createWallet(
            from: wallet,
            chains: chains
        )
        return Web3Alert.LocalSettings(
            remoteIdentifier: UUID().uuidString,
            pushToken: "",
            updatedAt: Date(),
            wallets: [web3Wallet],
            notifications: .init(
                stakingReward: .all,
                tokenSent: .all,
                tokenReceived: .all
            )
        )
    }

    func createWallet(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> Web3Alert.LocalWallet {
        let chainSpecific = wallet.chainAccounts.reduce(into: [Web3Alert.LocalChainId: AccountAddress]()) {
            if let chain = chains[$1.chainId] {
                let address = try? $1.accountId.toAddress(using: chain.chainFormat)
                $0[chain.chainId] = address ?? ""
            }
        }

        let substrateChainFormat = ChainFormat.substrate(UInt16(SNAddressType.genericSubstrate.rawValue))

        let model = Web3Alert.Wallet<Web3Alert.LocalChainId>(
            baseSubstrate: try? wallet.substrateAccountId?.toAddress(using: substrateChainFormat),
            baseEthereum: try? wallet.ethereumAddress?.toAddress(using: .ethereum),
            chainSpecific: chainSpecific
        )

        return .init(metaId: wallet.metaId, model: model)
    }
}
