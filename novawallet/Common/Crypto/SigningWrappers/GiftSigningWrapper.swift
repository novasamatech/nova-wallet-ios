import Foundation
import NovaCrypto
import Keystore_iOS
import SubstrateSdk

final class GiftSigningWrapper: BaseSigner, SigningWrapperProtocol {
    let giftSecretsManager: GiftSecretsManagerProtocol
    let accountId: AccountId
    let isEthereumBased: Bool
    let cryptoType: MultiassetCryptoType

    init(
        keystore: KeystoreProtocol,
        accountId: AccountId,
        isEthereumBased: Bool,
        cryptoType: MultiassetCryptoType,
        settingsManager: SettingsManagerProtocol
    ) {
        giftSecretsManager = GiftSecretsManager(keystore: keystore)
        self.accountId = accountId
        self.cryptoType = cryptoType
        self.isEthereumBased = isEthereumBased

        super.init(settingsManager: settingsManager)
    }

    override func signData(
        _ data: Data,
        context _: ExtrinsicSigningContext
    ) throws -> IRSignatureProtocol {
        let secretInfo = GiftSecretKeyInfo(
            accountId: accountId,
            ethereumBased: isEthereumBased
        )
        let secrets: GiftSecrets = try giftSecretsManager.getSecrets(for: secretInfo)

        let publicKeyRequest = GiftPublicKeyFetchRequest(
            seed: secrets.seed,
            ethereumBased: isEthereumBased
        )

        let publicKey: Data = try giftSecretsManager.getPublicKey(request: publicKeyRequest)
        let secretKey = secrets.secretKey

        return switch cryptoType {
        case .sr25519:
            try signSr25519(
                data,
                secretKeyData: secretKey,
                publicKeyData: publicKey
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
