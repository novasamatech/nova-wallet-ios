import Foundation
import NovaCrypto
import Keystore_iOS
import SubstrateSdk

final class GiftSigningWrapper: BaseSigner, SigningWrapperProtocol {
    let keystore: KeystoreProtocol
    let accountId: AccountId?
    let isEthereumBased: Bool
    let cryptoType: MultiassetCryptoType
    let publicKeyData: Data

    init(
        keystore: KeystoreProtocol,
        accountId: AccountId?,
        isEthereumBased: Bool,
        cryptoType: MultiassetCryptoType,
        publicKeyData: Data,
        settingsManager: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        self.accountId = accountId
        self.cryptoType = cryptoType
        self.isEthereumBased = isEthereumBased
        self.publicKeyData = publicKeyData

        super.init(settingsManager: settingsManager)
    }

    init(
        keystore: KeystoreProtocol,
        accountResponse: ChainAccountResponse,
        settingsManager: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        isEthereumBased = accountResponse.isEthereumBased
        cryptoType = accountResponse.cryptoType
        publicKeyData = accountResponse.publicKey

        super.init(settingsManager: settingsManager)
    }

    init(
        keystore: KeystoreProtocol,
        ethereumAccountResponse: MetaEthereumAccountResponse,
        settingsManager: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        accountId = ethereumAccountResponse.isChainAccount ? ethereumAccountResponse.address : nil
        isEthereumBased = true
        cryptoType = MultiassetCryptoType.ethereumEcdsa
        publicKeyData = ethereumAccountResponse.publicKey

        super.init(settingsManager: settingsManager)
    }

    override func signData(_ data: Data, context _: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        let tag: String = isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForGift(accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForGift(accountId: accountId)

        let secretKey = try keystore.fetchKey(for: tag)

        return switch cryptoType {
        case .sr25519:
            try signSr25519(
                data,
                secretKeyData: secretKey,
                publicKeyData: publicKeyData
            )
        case .ed25519:
            try signEd25519(
                data,
                secretKey: secretKey
            )
        case .substrateEcdsa:
            try signEcdsa(
                data,
                secretKey: secretKey
            )
        case .ethereumEcdsa:
            try signEthereum(
                data,
                secretKey: secretKey
            )
        }
    }
}
