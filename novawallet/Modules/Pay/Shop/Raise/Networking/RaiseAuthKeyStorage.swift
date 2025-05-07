import Foundation
import SubstrateSdk
import NovaCrypto
import Keystore_iOS
import MerlinTranscriptApi

protocol RaiseAuthKeyStorageProtocol {
    func fetchOrCreateKeypair() throws -> IRCryptoKeypairProtocol
    func sign(message: Data) throws -> Data
    func fetchAuthToken() -> RaiseAuthToken?
    func saveAuth(token: RaiseAuthToken?) throws
}

/**
 *  The class handles autorization key and token storage for Raise.
 *  Only substrate wallets seeds are supported.
 */
final class RaiseAuthKeyStorage {
    static let derivationPath = "//raise//auth"

    let keystore: KeystoreProtocol
    let account: ChainAccountResponse

    init(
        keystore: KeystoreProtocol,
        account: ChainAccountResponse
    ) {
        self.keystore = keystore
        self.account = account
    }
}

private extension RaiseAuthKeyStorage {
    private func getTokenTag() -> String {
        KeystoreTagV2.raiseTokenTagForMetaId(
            account.metaId,
            accountId: account.accountId
        )
    }

    private func getMainSeedTag() -> String {
        if account.isChainAccount {
            KeystoreTagV2.substrateSeedTagForMetaId(account.metaId, accountId: account.accountId)
        } else {
            KeystoreTagV2.substrateSeedTagForMetaId(account.metaId, accountId: nil)
        }
    }
}

extension RaiseAuthKeyStorage: RaiseAuthKeyStorageProtocol {
    func fetchOrCreateKeypair() throws -> IRCryptoKeypairProtocol {
        let seed = try keystore.fetchKey(for: getMainSeedTag())

        let keypairFactory = SR25519KeypairFactory()
        let chaincodeList = try SubstrateJunctionFactory().parse(
            path: Self.derivationPath
        ).chaincodes

        return try keypairFactory.createKeypairFromSeed(seed, chaincodeList: chaincodeList)
    }

    func sign(message: Data) throws -> Data {
        let keypair = try fetchOrCreateKeypair()
        let params = RaiseSignParams(
            publicKey: keypair.publicKey().rawData(),
            secret: keypair.privateKey().rawData(),
            message: message
        )

        return try RaiseTranscriptApi().signeMessage(for: params)
    }

    func fetchAuthToken() -> RaiseAuthToken? {
        let tokenTag = getTokenTag()
        if let tokenExists = try? keystore.checkKey(for: tokenTag), tokenExists {
            guard let data = try? keystore.fetchKey(for: tokenTag) else {
                return nil
            }

            return try? JSONDecoder().decode(RaiseAuthToken.self, from: data)
        } else {
            return nil
        }
    }

    func saveAuth(token: RaiseAuthToken?) throws {
        let tokenTag = getTokenTag()

        if let token {
            let tokenData = try JSONEncoder().encode(token)
            try keystore.saveKey(tokenData, with: tokenTag)
        } else {
            try keystore.deleteKeyIfExists(for: tokenTag)
        }
    }
}
