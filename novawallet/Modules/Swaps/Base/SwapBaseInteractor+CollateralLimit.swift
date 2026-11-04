import Foundation

extension SwapBaseInteractor {
    func provideCollateralLimit(for chainAsset: ChainAsset) {
        fetchCollateralLimit(for: chainAsset, retriesOnFailure: true)
    }

    func retryCollateralLimitIfNeeded(for chainAssetId: ChainAssetId) {
        guard let chainAsset = collateralLimitRetryChainAsset, chainAsset.chainAssetId == chainAssetId else {
            return
        }

        fetchCollateralLimit(for: chainAsset, retriesOnFailure: false)
    }
}

private extension SwapBaseInteractor {
    func fetchCollateralLimit(for chainAsset: ChainAsset, retriesOnFailure: Bool) {
        collateralLimitCallStore.cancel()
        collateralLimitRetryChainAsset = nil

        guard
            chainAsset.mayBackHydraAaveLoan,
            let accountId = chainAccountResponse(for: chainAsset)?.accountId else {
            return
        }

        let wrapper = collateralLimitFactory.createLimitWrapper(for: chainAsset, accountId: accountId)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: collateralLimitCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(limit):
                self?.basePresenter?.didReceive(collateralLimit: limit, for: chainAsset.chainAssetId)
            case let .failure(error):
                self?.logger.error("Collateral limit fetch failed: \(error)")
                self?.collateralLimitRetryChainAsset = retriesOnFailure ? chainAsset : nil
            }
        }
    }
}
