import UIKit
import Operation_iOS
import BigInt

final class SubstrateGiftClaimInteractor: GiftClaimInteractor {
    let claimDescriptionFactory: ClaimableGiftDescriptionFactoryProtocol
    let claimOperationFactory: SubstrateGiftClaimFactoryProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol

    let assetStorageCallStore = CancellableCallStore()
    var assetStorageInfo: AssetStorageInfo?

    init(
        claimDescriptionFactory: ClaimableGiftDescriptionFactoryProtocol,
        claimOperationFactory: SubstrateGiftClaimFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        claimableGift: ClaimableGiftInfo,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        walletOperationFactory: GiftClaimWalletOperationFactoryProtocol,
        logger: LoggerProtocol,
        totalAmount: BigUInt,
        operationQueue: OperationQueue
    ) {
        self.claimDescriptionFactory = claimDescriptionFactory
        self.claimOperationFactory = claimOperationFactory
        self.assetStorageInfoFactory = assetStorageInfoFactory

        super.init(
            chainRegistry: chainRegistry,
            claimableGift: claimableGift,
            walletOperationFactory: walletOperationFactory,
            logger: logger,
            totalAmount: totalAmount,
            operationQueue: operationQueue
        )
    }

    // MARK: - Override

    override func performSetup() {
        setupAssetInfo()
    }

    override func claimGift(giftDescription: ClaimableGiftDescription) {
        guard let assetStorageInfo else { return }

        let wrapper = claimOperationFactory.createClaimWrapper(
            giftDescription: giftDescription,
            assetStorageInfo: assetStorageInfo
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didClaimSuccessfully()
            case let .failure(error):
                self?.presenter?.didReceive(error)
            }
        }
    }
}

// MARK: - Private

private extension SubstrateGiftClaimInteractor {
    func setupAssetInfo() {
        guard let runtimeService = chainRegistry.getRuntimeProvider(
            for: claimableGift.chainAsset.chain.chainId
        ) else { return }

        let assetStorageWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: claimableGift.chainAsset.asset,
            runtimeProvider: runtimeService
        )

        executeCancellable(
            wrapper: assetStorageWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: assetStorageCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(info):
                self?.assetStorageInfo = info
                self?.continueSetup()
            case let .failure(error):
                self?.presenter?.didReceive(error)
                self?.logger.error("Failed on fetch asset storage info: \(error)")
            }
        }
    }

    func continueSetup() {
        guard let assetStorageInfo else { return }

        let walletWrapper = walletOperationFactory.createWrapper()

        let claimGiftDescriptionOperation = claimDescriptionFactory.createDescription(
            for: claimableGift,
            giftAmountWithFee: totalAmount,
            claimingWallet: { try walletWrapper.targetOperation.extractNoCancellableResultData().wallet },
            assetStorageInfo: { assetStorageInfo }
        )

        claimGiftDescriptionOperation.addDependency(walletWrapper.targetOperation)

        let resultWrapper = walletWrapper.insertingTail(operation: claimGiftDescriptionOperation)

        execute(
            wrapper: resultWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(giftDescription):
                self?.presenter?.didReceive(giftDescription)
            case let .failure(error):
                self?.presenter?.didReceive(error)
                self?.logger.error("Failed on setup: \(error)")
            }
        }
    }
}
