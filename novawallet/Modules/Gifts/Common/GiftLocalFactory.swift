import Foundation
import SubstrateSdk
import BigInt
import NovaCrypto
import Keystore_iOS
import Operation_iOS
import Scrypt

protocol LocalGiftFactoryProtocol {
    func createGiftOperation(
        from seed: Data?,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> BaseOperation<GiftModel>

    func getSecrets(
        for localGiftAccountId: AccountId,
        ethereumBased: Bool
    ) -> BaseOperation<GiftSecrets?>

    func cleanSecrets(
        for info: GiftSecretKeyInfo
    ) -> BaseOperation<Void>
}

extension LocalGiftFactoryProtocol {
    func createGiftOperation(
        from seed: Data? = nil,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> BaseOperation<GiftModel> {
        createGiftOperation(
            from: seed,
            amount: amount,
            chainAsset: chainAsset
        )
    }
}

final class LocalGiftFactory {
    private let metaId: MetaAccountModel.Id?
    private let keystore: KeystoreProtocol

    init(
        metaId: MetaAccountModel.Id? = nil,
        keystore: KeystoreProtocol
    ) {
        self.keystore = keystore
        self.metaId = metaId
    }
}

// MARK: - Private

private extension LocalGiftFactory {
    // MARK: - Create

    func createSeed() throws -> Data {
        guard let randomData = Data.random(of: 10) else {
            throw GiftFactoryError.seedCreationFailed
        }

        return randomData
    }

    func createKeyPair(
        from seed: Data,
        chain: ChainModel,
        chainCodes: [Chaincode]
    ) throws -> (publicKey: Data, secretKey: Data) {
        guard let saltBytes = Constants.salt.data(using: .utf8)?.byteArray else {
            throw GiftFactoryError.keyDerivationFailed
        }

        let seedHash = try scrypt(
            password: seed.byteArray,
            salt: saltBytes,
            length: 32
        )

        let cryptoType: MultiassetCryptoType = chain.isEthereumBased
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
            ? KeystoreTagV2.ethereumSeedTagForMetaId("", accountId: accountId)
            : KeystoreTagV2.substrateSeedTagForMetaId("", accountId: accountId)

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

// MARK: - LocalGiftFactoryProtocol

extension LocalGiftFactory: LocalGiftFactoryProtocol {
    func createGiftOperation(
        from seed: Data?,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> BaseOperation<GiftModel> {
        ClosureOperation { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let seed: Data = try (seed ?? createSeed())

            let ethereumBased = chainAsset.chain.isEthereumBased

            let junctionResult = try createJunctionResult(ethereumBased: ethereumBased)

            let keypair = try createKeyPair(
                from: seed,
                chain: chainAsset.chain,
                chainCodes: junctionResult?.chaincodes ?? []
            )

            let accountId = ethereumBased
                ? try keypair.publicKey.ethereumAddressFromPublicKey()
                : try keypair.publicKey.publicKeyToAccountId()

            try saveSeed(
                seed,
                accountId: accountId,
                ethereumBased: ethereumBased
            )
            try saveSecretKey(
                keypair.secretKey,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            return GiftModel(
                amount: amount,
                chainAssetId: chainAsset.chainAssetId,
                status: .pending,
                giftAccountId: accountId,
                senderMetaId: metaId
            )
        }
    }

    func getSecrets(
        for localGiftAccountId: AccountId,
        ethereumBased: Bool
    ) -> BaseOperation<GiftSecrets?> {
        ClosureOperation { [weak self] in
            guard let seed = try self?.loadSeed(
                accountId: localGiftAccountId,
                ethereumBased: ethereumBased
            ) else { return nil }

            return GiftSecrets(seed: seed)
        }
    }

    func cleanSecrets(
        for info: GiftSecretKeyInfo
    ) -> BaseOperation<Void> {
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

private extension LocalGiftFactory {
    enum Constants {
        static let salt: String = "Gift"
    }
}

enum GiftFactoryError: Error {
    case seedCreationFailed
    case keyDerivationFailed
}

struct GiftSecrets {
    let seed: Data
}
