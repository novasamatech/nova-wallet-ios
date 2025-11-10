import UIKit
import Operation_iOS
import BigInt

final class GiftClaimInteractor {
    weak var presenter: GiftClaimInteractorOutputProtocol?

    let claimDescriptionFactory: ClaimableGiftDescriptionFactoryProtocol
    let claimOperationFactory: SubstrateGiftClaimFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let walletOperationFactory: GiftClaimWalletOperationFactoryProtocol
    let logger: LoggerProtocol
    let operationQueue: OperationQueue

    let giftInfo: ClaimableGiftInfo
    let totalAmount: BigUInt

    let assetStorageCallStore = CancellableCallStore()

    var assetStorageInfo: AssetStorageInfo?

    init(
        claimDescriptionFactory: ClaimableGiftDescriptionFactoryProtocol,
        claimOperationFactory: SubstrateGiftClaimFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        giftInfo: ClaimableGiftInfo,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        walletOperationFactory: GiftClaimWalletOperationFactoryProtocol,
        logger: LoggerProtocol,
        operationQueue: OperationQueue,
        totalAmount: BigUInt
    ) {
        self.claimDescriptionFactory = claimDescriptionFactory
        self.claimOperationFactory = claimOperationFactory
        self.chainRegistry = chainRegistry
        self.assetStorageInfoFactory = assetStorageInfoFactory
        self.walletOperationFactory = walletOperationFactory
        self.logger = logger
        self.operationQueue = operationQueue
        self.totalAmount = totalAmount
        self.giftInfo = giftInfo
    }
}

// MARK: - Private

private extension GiftClaimInteractor {
    func setupAssetInfo() {
        guard
            let chain = chainRegistry.getChain(for: giftInfo.chainId),
            let chainAsset = chain.chainAssetForSymbol(giftInfo.assetSymbol),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)
        else { return }

        let assetStorageWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: chainAsset.asset,
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
            for: giftInfo,
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

// MARK: - GiftClaimInteractorInputProtocol

extension GiftClaimInteractor: GiftClaimInteractorInputProtocol {
    func setup() {
        setupAssetInfo()
    }

    func claimGift(with giftDescription: ClaimableGiftDescription) {
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
