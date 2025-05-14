import Foundation
import NovaCrypto
import Keystore_iOS
import SubstrateSdk

enum SigningWrapperError: Error {
    case missingSelectedAccount
    case missingSecretKey
    case pinCheckNotPassed
}

final class SigningWrapper: BaseSigner, SigningWrapperProtocol {
    let keystore: KeystoreProtocol
    let metaId: String
    let accountId: AccountId?
    let isEthereumBased: Bool
    let cryptoType: MultiassetCryptoType
    let publicKeyData: Data

    init(
        keystore: KeystoreProtocol,
        metaId: String,
        accountId: AccountId?,
        isEthereumBased: Bool,
        cryptoType: MultiassetCryptoType,
        publicKeyData: Data,
        settingsManager: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        self.metaId = metaId
        self.accountId = accountId
        self.cryptoType = cryptoType
        self.isEthereumBased = isEthereumBased
        self.publicKeyData = publicKeyData

        super.init(settingsManager: settingsManager)
    }

    init(
        keystore: KeystoreProtocol,
        metaId: String,
        accountResponse: ChainAccountResponse,
        settingsManager: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        self.metaId = metaId
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
        metaId = ethereumAccountResponse.metaId
        accountId = ethereumAccountResponse.isChainAccount ? ethereumAccountResponse.address : nil
        isEthereumBased = true
        cryptoType = MultiassetCryptoType.ethereumEcdsa
        publicKeyData = ethereumAccountResponse.publicKey

        super.init(settingsManager: settingsManager)
    }

    override func signData(_ data: Data, context _: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        let tag: String = isEthereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

        let secretKey = try keystore.fetchKey(for: tag)

        switch cryptoType {
        case .sr25519:
            return try signSr25519(data, secretKeyData: secretKey, publicKeyData: publicKeyData)
        case .ed25519:
            return try signEd25519(data, secretKey: secretKey)
        case .substrateEcdsa:
            return try signEcdsa(data, secretKey: secretKey)
        case .ethereumEcdsa:
            return try signEthereum(data, secretKey: secretKey)
        }
    }
}
