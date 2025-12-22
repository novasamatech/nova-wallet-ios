import UIKit
import Operation_iOS
import BigInt

final class SubstrateGiftClaimInteractor: GiftClaimInteractor {
    let claimDescriptionFactory: SubstrateGiftDescriptionFactoryProtocol
    let claimOperationFactory: SubstrateGiftClaimFactoryProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol

    let assetStorageCallStore = CancellableCallStore()
    var assetStorageInfo: AssetStorageInfo?

    init(
        claimDescriptionFactory: SubstrateGiftDescriptionFactoryProtocol,
        claimOperationFactory: SubstrateGiftClaimFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        claimableGift: ClaimGiftPayload,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        walletOperationFactory: GiftClaimWalletOperationFactoryProtocol,
        walletListLocalSubscriptionFactory: WalletListLocalSubscriptionFactoryProtocol,
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
            walletListLocalSubscriptionFactory: walletListLocalSubscriptionFactory,
            logger: logger,
            totalAmount: totalAmount,
            operationQueue: operationQueue
        )
    }

    // MARK: - Override

    override func performSetup(with wallet: MetaAccountModel?) {
        setupAssetInfo(with: wallet)
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
    func setupAssetInfo(with wallet: MetaAccountModel?) {
        guard assetStorageInfo == nil else {
            continueSetup(with: wallet)
            return
        }

        guard
            let chain = chainRegistry.getChain(for: claimableGift.chainAssetId.chainId),
            let asset = chain.asset(for: claimableGift.chainAssetId.assetId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId)
        else { return }

        let assetStorageWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: asset,
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
                self?.continueSetup(with: wallet)
            case let .failure(error):
                self?.presenter?.didReceive(error)
                self?.logger.error("Failed on fetch asset storage info: \(error)")
            }
        }
    }

    func continueSetup(with wallet: MetaAccountModel?) {
        setupGift(selectedWallet: wallet)
    }

    func setupGift(selectedWallet: MetaAccountModel?) {
        guard let assetStorageInfo else { return }

        let wrapper = createSetupWrapper(
            for: assetStorageInfo,
            selectedWallet: selectedWallet
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(setupResult):
                self?.giftedWallet = setupResult.giftedWallet
                self?.presenter?.didReceive(setupResult)
            case let .failure(error):
                self?.presenter?.didReceive(error)
                self?.logger.error("Failed on setup: \(error)")
            }
        }
    }

    func createSetupWrapper(
        for assetStorageInfo: AssetStorageInfo,
        selectedWallet: MetaAccountModel?
    ) -> CompoundOperationWrapper<GiftClaimInteractor.ClaimSetupResult> {
        let walletWrapper = walletOperationFactory.createWrapper(selectedWallet: selectedWallet)

        let claimGiftDescriptionOperation = claimDescriptionFactory.createDescription(
            for: claimableGift,
            giftAmountWithFee: totalAmount,
            claimingWallet: { try walletWrapper.targetOperation.extractNoCancellableResultData().wallet },
            assetStorageInfo: { assetStorageInfo }
        )

        claimGiftDescriptionOperation.addDependency(walletWrapper.targetOperation)

        let resultOperation = ClosureOperation {
            let giftedWallet = try walletWrapper.targetOperation.extractNoCancellableResultData()
            let giftDescription = try claimGiftDescriptionOperation.extractNoCancellableResultData()

            return GiftClaimInteractor.ClaimSetupResult(
                giftedWallet: giftedWallet,
                giftDescription: giftDescription
            )
        }

        resultOperation.addDependency(claimGiftDescriptionOperation)

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: [claimGiftDescriptionOperation] + walletWrapper.allOperations
        )
    }
}
