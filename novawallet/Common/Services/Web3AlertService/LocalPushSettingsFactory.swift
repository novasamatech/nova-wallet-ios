import SubstrateSdk

protocol LocalPushSettingsFactoryProtocol {
    func createSettings(
        for wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> LocalPushSettings

    func createWallet(
        from wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> Web3AlertWallet
}

final class LocalPushSettingsFactory: LocalPushSettingsFactoryProtocol {
    func createSettings(
        for wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> LocalPushSettings {
        let web3Wallet = createWallet(
            from: wallet,
            chains: chains
        )
        return LocalPushSettings(
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
    ) -> Web3AlertWallet {
        let chainSpecific = wallet.chainAccounts.reduce(into: [Web3AlertWallet.ChainId: AccountAddress]()) {
            if let chainFormat = chains[$1.chainId]?.chainFormat {
                let address = try? $1.accountId.toAddress(using: chainFormat)
                $0[$1.chainId] = address ?? ""
            }
        }

        let substrateChainFormat = ChainFormat.substrate(UInt16(SNAddressType.genericSubstrate.rawValue))
        return Web3AlertWallet(
            baseSubstrate: try? wallet.substrateAccountId?.toAddress(using: substrateChainFormat),
            baseEthereum: try? wallet.ethereumAddress?.toAddress(using: .ethereum),
            chainSpecific: chainSpecific
        )
    }
}
