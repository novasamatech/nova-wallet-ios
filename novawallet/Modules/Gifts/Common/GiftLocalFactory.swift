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
}

final class GiftLocalFactory {
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }
}

// MARK: - Private

private extension GiftLocalFactory {
    func createSeed() throws -> Data {
        try BIP32SeedFactory().createSeed(
            from: "",
            strength: .entropy128
        )
        .seed
        .subdata(in: 0 ..< 10)
        + Data(repeating: 0x20, count: 22)
    }

    func createKeyPair(
        from seed: Data,
        chain: ChainModel
    ) throws -> (publicKey: Data, secretKey: Data) {
        let cryptoType: MultiassetCryptoType = chain.isEthereumBased
            ? .ethereumEcdsa
            : .sr25519
        let keypairFactory = createKeypairFactory(cryptoType)

        let keypair = try keypairFactory.createKeypairFromSeed(
            seed,
            chaincodeList: []
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

    func saveSecretKey(
        _ secretKey: Data,
        accountId: AccountId,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId("", accountId: accountId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId("", accountId: accountId)

        try keystore.saveKey(secretKey, with: tag)
    }

    func saveSeed(
        _ seed: Data,
        accountId: AccountId,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased ?
            KeystoreTagV2.ethereumSeedTagForMetaId("", accountId: accountId) :
            KeystoreTagV2.substrateSeedTagForMetaId("", accountId: accountId)

        try keystore.saveKey(seed, with: tag)
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

            let seed = try createSeed()
            let keypair = try createKeyPair(from: seed, chain: chainAsset.chain)

            let accountId = try keypair.publicKey.publicKeyToAccountId()

            try saveSeed(
                seed,
                accountId: accountId,
                ethereumBased: chainAsset.chain.isEthereumBased
            )
            try saveSecretKey(
                keypair.secretKey,
                accountId: accountId,
                ethereumBased: chainAsset.chain.isEthereumBased
            )

            return GiftModel(
                amount: amount,
                chainAssetId: chainAsset.chainAssetId,
                status: .pending,
                giftAccountId: accountId
            )
        }
    }
}
