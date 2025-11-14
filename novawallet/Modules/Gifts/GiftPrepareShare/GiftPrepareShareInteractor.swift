import UIKit
import Operation_iOS

final class GiftPrepareShareInteractor {
    weak var presenter: GiftPrepareShareInteractorOutputProtocol?

    let giftId: GiftModel.Id
    let giftSecretsManager: GiftSecretsProvidingProtocol
    let giftRepository: AnyDataProviderRepository<GiftModel>
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    let logger: LoggerProtocol

    var chainAsset: ChainAsset?

    init(
        giftRepository: AnyDataProviderRepository<GiftModel>,
        giftSecretsManager: GiftSecretsManagerProtocol,
        chainRegistry: ChainRegistryProtocol,
        giftId: GiftModel.Id,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.giftRepository = giftRepository
        self.giftSecretsManager = giftSecretsManager
        self.chainRegistry = chainRegistry
        self.giftId = giftId
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension GiftPrepareShareInteractor {
    func provideData(for giftId: GiftModel.Id) {
        let fetchOperation = giftRepository.fetchOperation(
            by: { giftId.toHex() },
            options: .init()
        )

        execute(
            operation: fetchOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(gift):
                guard
                    let gift,
                    let chain = chainRegistry.getChain(for: gift.chainAssetId.chainId),
                    let chainAsset = chain.chainAsset(for: gift.chainAssetId.assetId)
                else { return }

                let outputModel = GiftPrepareShareInteractorOutputData(
                    chainAsset: chainAsset,
                    gift: gift
                )

                presenter?.didReceive(outputModel)
            case let .failure(error):
                presenter?.didReceive(error)
                logger.error("Failed on fetch local gift: \(error)")
            }
        }
    }

    func createSharingPayload(
        with secrets: GiftSecrets,
        chainAsset: ChainAsset
    ) -> GiftSharingPayload {
        let chainId = chainAsset.chainAssetId.chainId.split(by: .colon).last ?? ""

        return GiftSharingPayload(
            seed: secrets.seed.toHexString(),
            chainId: chainId,
            assetSymbol: chainAsset.asset.symbol
        )
    }
}

extension GiftPrepareShareInteractor: GiftPrepareShareInteractorInputProtocol {
    func setup() {
        provideData(for: giftId)
    }

    func share(
        gift: GiftModel,
        chainAsset: ChainAsset
    ) {
        let secretInfo = GiftSecretKeyInfo(
            accountId: gift.giftAccountId,
            ethereumBased: chainAsset.chain.isEthereumBased
        )
        let secretsOperation: BaseOperation<GiftSecrets> = giftSecretsManager.getSecrets(for: secretInfo)

        execute(
            operation: secretsOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(secrets):
                let payload = createSharingPayload(with: secrets, chainAsset: chainAsset)
                presenter?.didReceive(payload)
            case let .failure(error):
                presenter?.didReceive(error)
                logger.error("Failed on fetch secrets for gift: \(error)")
            }
        }
    }
}

struct GiftPrepareShareInteractorOutputData {
    let chainAsset: ChainAsset
    let gift: GiftModel
}

struct GiftSharingPayload {
    let seed: String
    let chainId: ChainModel.Id
    let assetSymbol: AssetModel.Symbol
}
