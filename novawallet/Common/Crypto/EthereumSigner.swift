import Foundation
import IrohaCrypto
import SoraKeystore
import SubstrateSdk

final class EthereumSigner {
    let keystore: KeystoreProtocol
    let metaId: String
    let accountId: AccountId?
    let publicKeyData: Data

    init(keystore: KeystoreProtocol, ethereumAccountResponse: MetaEthereumAccountResponse) {
        self.keystore = keystore
        metaId = ethereumAccountResponse.metaId
        accountId = ethereumAccountResponse.isChainAccount ? ethereumAccountResponse.address : nil
        publicKeyData = ethereumAccountResponse.publicKey
    }

    func sign(hashedData: Data) throws -> IRSignatureProtocol {
        let tag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)

        let secretKey = try keystore.fetchKey(for: tag)

        let keypairFactory = EcdsaKeypairFactory()
        let privateKey = try keypairFactory
            .createKeypairFromSeed(secretKey.miniSeed, chaincodeList: [])
            .privateKey()

        let signer = SECSigner(privateKey: privateKey)

        return try signer.sign(hashedData)
    }
}
