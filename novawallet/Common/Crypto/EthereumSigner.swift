import Foundation
import NovaCrypto
import Keystore_iOS
import SubstrateSdk

final class EthereumSigner: BaseSigner {
    let keystore: KeystoreProtocol
    let metaId: String
    let accountId: AccountId?
    let publicKeyData: Data

    init(
        keystore: KeystoreProtocol,
        ethereumAccountResponse: MetaEthereumAccountResponse,
        settingsManager: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        metaId = ethereumAccountResponse.metaId
        accountId = ethereumAccountResponse.isChainAccount ? ethereumAccountResponse.address : nil
        publicKeyData = ethereumAccountResponse.publicKey

        super.init(settingsManager: settingsManager)
    }

    override func signData(_ data: Data, context _: ExtrinsicSigningContext) throws -> IRSignatureProtocol {
        let tag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)

        let secretKey = try keystore.fetchKey(for: tag)

        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        return try signer.sign(data)
    }
}
