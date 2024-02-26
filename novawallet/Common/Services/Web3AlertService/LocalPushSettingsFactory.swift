import SubstrateSdk

protocol LocalPushSettingsFactoryProtocol {
    func createSettings(
        for wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> LocalPushSettings
}

final class LocalPushSettingsFactory: LocalPushSettingsFactoryProtocol {
    func createSettings(
        for wallet: MetaAccountModel,
        chains: [ChainModel.Id: ChainModel]
    ) -> LocalPushSettings {
        let chainSpecific = wallet.chainAccounts.reduce(into: [Web3AlertWallet.ChainId: AccountAddress]()) {
            if let chainFormat = chains[$1.chainId]?.chainFormat {
                let address = try? $1.accountId.toAddress(using: chainFormat)
                $0[$1.chainId] = address ?? ""
            }
        }

        let substrateChainFormat = ChainFormat.substrate(UInt16(SNAddressType.genericSubstrate.rawValue))
        let web3Wallet = Web3AlertWallet(
            baseSubstrate: try? wallet.substrateAccountId?.toAddress(using: substrateChainFormat),
            baseEthereum: try? wallet.ethereumAddress?.toAddress(using: .ethereum),
            chainSpecific: chainSpecific
        )
        return LocalPushSettings(
            remoteIdentifier: UUID().uuidString,
            pushToken: "",
            updatedAt: Date(),
            wallets: [web3Wallet],
            notifications: .init(
                stakingReward: nil,
                transfer: nil,
                tokenSent: true,
                tokenReceived: true
            )
        )
    }
}
