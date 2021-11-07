import Foundation
import SoraKeystore
import SubstrateSdk
import IrohaCrypto

protocol KeystoreExportWrapperProtocol {
    func export(account: AccountItem, password: String?) throws -> Data
    func export(metaAccount: MetaAccountModel, chain: ChainModel, password: String?) throws -> Data
}

enum KeystoreExportWrapperError: Error {
    case missingSecretKey
}

final class KeystoreExportWrapper: KeystoreExportWrapperProtocol {
    let keystore: KeystoreProtocol

    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private lazy var ss58Factory = SS58AddressFactory()

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func export(account: AccountItem, password: String?) throws -> Data {
        guard let secretKey = try keystore.fetchSecretKeyForAddress(account.address) else {
            throw KeystoreExportWrapperError.missingSecretKey
        }

        let addressType = try ss58Factory.type(fromAddress: account.address)

        var builder = KeystoreBuilder()
            .with(name: account.username)

        if let genesisHash = SNAddressType(rawValue: addressType.uint8Value)?.chain.genesisHash,
           let genesisHashData = try? Data(hexString: genesisHash) {
            builder = builder.with(genesisHash: genesisHashData.toHex(includePrefix: true))
        }

        let keystoreData = KeystoreData(
            address: account.address,
            secretKeyData: secretKey,
            publicKeyData: account.publicKeyData,
            secretType: account.cryptoType.secretType
        )

        let definition = try builder.build(from: keystoreData, password: password)

        return try jsonEncoder.encode(definition)
    }

    func export(metaAccount: MetaAccountModel, chain: ChainModel, password: String?) throws -> Data {
        let accountRequest = chain.accountRequest()

        guard let accountResponse = metaAccount.fetch(for: accountRequest) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        let accountId = metaAccount.fetchChainAccountId(for: accountRequest)

        let tag = chain.isEthereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaAccount.metaId, accountId: accountId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId(metaAccount.metaId, accountId: accountId)
        guard let secretKey = try keystore.loadIfKeyExists(tag) else {
            throw KeystoreExportWrapperError.missingSecretKey
        }

        var builder = KeystoreBuilder().with(name: accountResponse.name)

        if let genesisHashData = try? Data(hexString: chain.chainId) {
            builder = builder.with(genesisHash: genesisHashData.toHex(includePrefix: true))
        }

        let address: String? = {
            if accountResponse.isEthereumBased {
                return accountResponse.publicKey.toHex(includePrefix: true)
            } else {
                return accountResponse.toAddress()
            }
        }()

        let keystoreData = KeystoreData(
            address: address,
            secretKeyData: secretKey,
            publicKeyData: accountResponse.publicKey,
            secretType: accountResponse.cryptoType.secretType
        )

        let definition = try builder.build(from: keystoreData, password: password)

        return try jsonEncoder.encode(definition)
    }
}
