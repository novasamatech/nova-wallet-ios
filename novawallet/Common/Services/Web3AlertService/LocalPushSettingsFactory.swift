import SubstrateSdk

protocol LocalPushSettingsFactoryProtocol {
    func createSettings(
        for wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> Web3Alert.LocalSettings

    func createWallet(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> Web3Alert.LocalWallet
}

final class LocalPushSettingsFactory: LocalPushSettingsFactoryProtocol {
    func createSettings(
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
                stakingReward: nil,
                transfer: nil,
                tokenSent: .all,
                tokenReceived: .all
            )
        )
    }

    func createWallet(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> Web3Alert.LocalWallet {
        let chainSpecific = wallet.chainAccounts.reduce(into: [Web3Alert.ChainId: AccountAddress]()) {
            if let chainFormat = chains[$1.chainId]?.chainFormat {
                let address = try? $1.accountId.toAddress(using: chainFormat)
                $0[$1.chainId] = address ?? ""
            }
        }

        let substrateChainFormat = ChainFormat.substrate(UInt16(SNAddressType.genericSubstrate.rawValue))

        let remoteWallet = Web3Alert.Wallet(
            baseSubstrate: try? wallet.substrateAccountId?.toAddress(using: substrateChainFormat),
            baseEthereum: try? wallet.ethereumAddress?.toAddress(using: .ethereum),
            chainSpecific: chainSpecific
        )

        return .init(metaId: wallet.metaId, remoteModel: remoteWallet)
    }
}
