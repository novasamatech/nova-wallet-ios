import UIKit
import RobinHood
import BigInt

final class SwapSetupInteractor: SwapBaseInteractor {
    weak var presenter: SwapSetupInteractorOutputProtocol? {
        basePresenter as? SwapSetupInteractorOutputProtocol
    }

    private var receiveChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions(activeChainAssets: activeChainAssets)
        }
    }

    private var payChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions(activeChainAssets: activeChainAssets)
        }
    }

    private var feeChainAsset: ChainAsset? {
        didSet {
            updateSubscriptions(activeChainAssets: activeChainAssets)
        }
    }

    private var activeChainAssets: Set<ChainAssetId> {
        Set(
            [
                receiveChainAsset?.chainAssetId,
                payChainAsset?.chainAssetId,
                feeChainAsset?.chainAssetId,
                feeChainAsset?.chain.utilityChainAssetId()
            ].compactMap { $0 }
        )
    }

    private var canPayFeeInAssetCall = CancellableCallStore()

    deinit {
        canPayFeeInAssetCall.cancel()
    }

    private func provideCanPayFee(for asset: ChainAsset) {
        canPayFeeInAssetCall.cancel()

        guard let utilityAssetId = asset.chain.utilityChainAssetId() else {
            presenter?.didReceiveCanPayFeeInPayAsset(false, chainAssetId: asset.chainAssetId)
            return
        }

        let wrapper = assetConversionAggregator.createAvailableDirectionsWrapper(for: asset)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: canPayFeeInAssetCall,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(chainAssetIds):
                let canPayFee = chainAssetIds.contains(utilityAssetId)
                self?.presenter?.didReceiveCanPayFeeInPayAsset(canPayFee, chainAssetId: asset.chainAssetId)
            case let .failure(error):
                self?.presenter?.didReceive(setupError: .payAssetSetFailed(error))
            }
        }
    }
}

extension SwapSetupInteractor: SwapSetupInteractorInputProtocol {
    func update(receiveChainAsset: ChainAsset?) {
        self.receiveChainAsset = receiveChainAsset
        receiveChainAsset.map {
            set(receiveChainAsset: $0)
        }
    }

    func update(payChainAsset: ChainAsset?) {
        self.payChainAsset = payChainAsset

        if let payChainAsset = payChainAsset {
            set(payChainAsset: payChainAsset)
            provideCanPayFee(for: payChainAsset)
        }
    }

    func update(feeChainAsset: ChainAsset?) {
        self.feeChainAsset = feeChainAsset
        feeChainAsset.map {
            set(feeChainAsset: $0)
        }
    }
}
