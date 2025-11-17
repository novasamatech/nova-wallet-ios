import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt
import NovaCrypto
import Keystore_iOS

protocol GiftOperationFactoryProtocol {
    func createGiftWrapper(
        from seed: Data?,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<GiftModel>
}

extension GiftOperationFactoryProtocol {
    func createGiftWrapper(
        from seed: Data? = nil,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<GiftModel> {
        createGiftWrapper(
            from: seed,
            amount: amount,
            chainAsset: chainAsset
        )
    }
}

final class GiftOperationFactory {
    private let metaId: MetaAccountModel.Id?
    private let secretsManager: GiftSecretsManagerProtocol

    init(
        metaId: MetaAccountModel.Id? = nil,
        secretsManager: GiftSecretsManagerProtocol
    ) {
        self.secretsManager = secretsManager
        self.metaId = metaId
    }
}

// MARK: - GiftOperationFactoryProtocol

extension GiftOperationFactory: GiftOperationFactoryProtocol {
    func createGiftWrapper(
        from seed: Data?,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<GiftModel> {
        let secretCreationRequest = GiftSecretCreationRequest(
            seed: seed,
            ethereumBased: chainAsset.chain.isEthereumBased
        )

        let secretsOperation = secretsManager.createSecrets(request: secretCreationRequest)

        let mapOperation = ClosureOperation { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let accountId = try secretsOperation.extractNoCancellableResultData()

            return GiftModel(
                amount: amount,
                chainAssetId: chainAsset.chainAssetId,
                status: .created,
                giftAccountId: accountId,
                creationDate: Date(),
                senderMetaId: metaId
            )
        }

        mapOperation.addDependency(secretsOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [secretsOperation]
        )
    }
}
