import Foundation
import SubstrateSdk
import BigInt
import NovaCrypto
import Keystore_iOS
import Operation_iOS
import Scrypt

final class GiftSecretsManager {
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }
}

// MARK: - Private

private extension GiftSecretsManager {
    // MARK: - Create

    func createSeed() throws -> Data {
        guard let randomData = Data.random(of: 10) else {
            throw GiftSecretsManagerError.seedCreationFailed
        }

        return randomData
    }

    func createKeyPair(
        seed: Data,
        ethereumBased: Bool,
        chainCodes: [Chaincode]
    ) throws -> (publicKey: Data, secretKey: Data) {
        guard let saltBytes = Constants.salt.data(using: .utf8)?.byteArray else {
            throw GiftSecretsManagerError.keyDerivationFailed
        }

        let seedHash = try scrypt(
            password: seed.byteArray,
            salt: saltBytes,
            length: 32
        )

        let cryptoType: MultiassetCryptoType = ethereumBased
            ? .ethereumEcdsa
            : .sr25519
        let keypairFactory = createKeypairFactory(cryptoType)

        let keypair = try keypairFactory.createKeypairFromSeed(
            Data(seedHash),
            chaincodeList: chainCodes
        )

        return (
            publicKey: keypair.publicKey().rawData(),
            secretKey: keypair.privateKey().rawData()
        )
    }

    func createKeypairFactory(_ cryptoType: MultiassetCryptoType) -> KeypairFactoryProtocol {
        switch cryptoType {
        case .sr25519:
            return SR25519KeypairFactory()
        case .ed25519:
            return Ed25519KeypairFactory()
        case .substrateEcdsa:
            return EcdsaKeypairFactory()
        case .ethereumEcdsa:
            return BIP32Secp256KeypairFactory()
        }
    }

    func createJunctionResult(
        ethereumBased: Bool
    ) throws -> JunctionResult? {
        guard ethereumBased else { return nil }

        return try BIP32JunctionFactory().parse(
            path: DerivationPathConstants.defaultEthereum
        )
    }

    // MARK: - Save

    func saveSecretKey(
        _ secretKey: Data,
        accountId: AccountId,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForGift(accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForGift(accountId: accountId)

        try keystore.saveKey(secretKey, with: tag)
    }

    func saveSeed(
        _ seed: Data,
        accountId: AccountId,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased
            ? KeystoreTagV2.ethereumSeedTagForGift(accountId: accountId)
            : KeystoreTagV2.substrateSeedTagForGift(accountId: accountId)

        try keystore.saveKey(seed, with: tag)
    }

    // MARK: - Load

    func loadSeed(
        accountId: AccountId,
        ethereumBased: Bool
    ) throws -> Data? {
        let tag = ethereumBased
            ? KeystoreTagV2.ethereumSeedTagForGift(accountId: accountId)
            : KeystoreTagV2.substrateSeedTagForGift(accountId: accountId)

        return try keystore.loadIfKeyExists(tag)
    }

    // MARK: - Remove

    func removeSeed(
        accountId: AccountId,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased
            ? KeystoreTagV2.ethereumSeedTagForGift(accountId: accountId)
            : KeystoreTagV2.substrateSeedTagForGift(accountId: accountId)

        try keystore.deleteKeyIfExists(for: tag)
    }

    func removeSecretKey(
        accountId: AccountId,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForGift(accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForGift(accountId: accountId)

        try keystore.deleteKeyIfExists(for: tag)
    }
}

// MARK: - GiftSecretsManagerProtocol

extension GiftSecretsManager: GiftSecretsManagerProtocol {
    func createSecrets(request: GiftSecretCreationRequest) -> BaseOperation<AccountId> {
        ClosureOperation {
            let junctionResult = try self.createJunctionResult(ethereumBased: request.ethereumBased)

            let seed = try (request.seed ?? self.createSeed())

            let keypair = try self.createKeyPair(
                seed: seed,
                ethereumBased: request.ethereumBased,
                chainCodes: junctionResult?.chaincodes ?? []
            )

            let accountId = request.ethereumBased
                ? try keypair.publicKey.ethereumAddressFromPublicKey()
                : try keypair.publicKey.publicKeyToAccountId()

            try self.saveSeed(
                seed,
                accountId: accountId,
                ethereumBased: request.ethereumBased
            )
            try self.saveSecretKey(
                keypair.secretKey,
                accountId: accountId,
                ethereumBased: request.ethereumBased
            )

            return accountId
        }
    }

    func getSecrets(for info: GiftSecretKeyInfo) -> BaseOperation<GiftSecrets?> {
        ClosureOperation { [weak self] in
            guard let seed = try self?.loadSeed(
                accountId: info.accountId,
                ethereumBased: info.ethereumBased
            ) else { return nil }

            return GiftSecrets(seed: seed)
        }
    }

    func getPublicKey(request: GiftPublicKeyFetchRequest) -> BaseOperation<AccountId> {
        ClosureOperation {
            let junctionResult = try self.createJunctionResult(ethereumBased: request.ethereumBased)

            let keypair = try self.createKeyPair(
                seed: request.seed,
                ethereumBased: request.ethereumBased,
                chainCodes: junctionResult?.chaincodes ?? []
            )

            let accountId = request.ethereumBased
                ? try keypair.publicKey.ethereumAddressFromPublicKey()
                : try keypair.publicKey.publicKeyToAccountId()

            return accountId
        }
    }

    func cleanSecrets(for info: GiftSecretKeyInfo) -> BaseOperation<Void> {
        ClosureOperation {
            try self.removeSeed(
                accountId: info.accountId,
                ethereumBased: info.ethereumBased
            )
            try self.removeSecretKey(
                accountId: info.accountId,
                ethereumBased: info.ethereumBased
            )
        }
    }
}

private extension GiftSecretsManager {
    enum Constants {
        static let salt: String = "Gift"
    }
}

enum GiftSecretsManagerError: Error {
    case seedCreationFailed
    case keyDerivationFailed
}

struct GiftSecrets {
    let seed: Data
}
