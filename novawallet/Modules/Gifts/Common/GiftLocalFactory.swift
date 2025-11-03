import Foundation
import SubstrateSdk
import BigInt
import NovaCrypto
import Keystore_iOS
import Operation_iOS

protocol GiftLocalFactoryProtocol {
    func createGiftOperation(
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> BaseOperation<GiftModel>

    func getSecrets(
        for localGiftAccountId: AccountId,
        ethereumBased: Bool
    ) -> BaseOperation<GiftSecrets?>

    func cleanSecrets(
        for localGiftAccountId: AccountId,
        ethereumBased: Bool
    ) -> BaseOperation<Void>
}

final class GiftLocalFactory {
    private let metaId: MetaAccountModel.Id
    private let keystore: KeystoreProtocol

    init(
        metaId: MetaAccountModel.Id,
        keystore: KeystoreProtocol
    ) {
        self.keystore = keystore
        self.metaId = metaId
    }
}

// MARK: - Private

private extension GiftLocalFactory {
    // MARK: - Create

    func createSeed(ethereumBased: Bool) throws -> Data {
        try createSeedFactory(ethereumBased: ethereumBased)
            .createSeed(
                from: "",
                strength: .entropy128
            )
            .seed
            .subdata(in: 0 ..< 10)
            // pad the rest
            + Data(repeating: 0x20, count: 22)
    }

    func createSeedFactory(ethereumBased: Bool) -> SeedFactoryProtocol {
        // Actually, there is no difference since we take only first 10 bytes
        ethereumBased ? BIP32SeedFactory() : SeedFactory()
    }

    func createKeyPair(
        from seed: Data,
        chain: ChainModel,
        chainCodes: [Chaincode]
    ) throws -> (publicKey: Data, secretKey: Data) {
        let cryptoType: MultiassetCryptoType = chain.isEthereumBased
            ? .ethereumEcdsa
            : .sr25519
        let keypairFactory = createKeypairFactory(cryptoType)

        let keypair = try keypairFactory.createKeypairFromSeed(
            seed,
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
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId("", accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId("", accountId: accountId)

        try keystore.saveKey(secretKey, with: tag)
    }

    func saveSeed(
        _ seed: Data,
        accountId: AccountId,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased
            ? KeystoreTagV2.ethereumSeedTagForMetaId("", accountId: accountId)
            : KeystoreTagV2.substrateSeedTagForMetaId("", accountId: accountId)

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
            ? KeystoreTagV2.ethereumSeedTagForMetaId("", accountId: accountId)
            : KeystoreTagV2.substrateSeedTagForMetaId("", accountId: accountId)

        try keystore.deleteKeyIfExists(for: tag)
    }

    func removeSecretKey(
        accountId: AccountId,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId("", accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId("", accountId: accountId)

        try keystore.deleteKeyIfExists(for: tag)
    }
}

// MARK: - GiftLocalFactoryProtocol

extension GiftLocalFactory: GiftLocalFactoryProtocol {
    func createGiftOperation(
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> BaseOperation<GiftModel> {
        ClosureOperation { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let ethereumBased = chainAsset.chain.isEthereumBased

            let junctionResult = try createJunctionResult(ethereumBased: ethereumBased)

            let seed = try createSeed(ethereumBased: ethereumBased)

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
                metaId: metaId
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
        for localGiftAccountId: AccountId,
        ethereumBased: Bool
    ) -> BaseOperation<Void> {
        ClosureOperation {
            try self.removeSeed(
                accountId: localGiftAccountId,
                ethereumBased: ethereumBased
            )
            try self.removeSecretKey(
                accountId: localGiftAccountId,
                ethereumBased: ethereumBased
            )
        }
    }
}

struct GiftSecrets {
    let seed: Data
}
