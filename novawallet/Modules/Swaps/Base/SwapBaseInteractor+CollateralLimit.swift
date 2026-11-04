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

        guard chainAsset.mayBackHydraAaveLoan else {
            return
        }

        let wrapper = chainAccountResponse(for: chainAsset).map {
            collateralLimitFactory.createLimitWrapper(for: chainAsset, accountId: $0.accountId)
        } ?? .createWithResult(.unrestricted)

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
                self?.basePresenter?.didReceive(baseError: .collateralLimit(error, chainAsset.chainAssetId))
            }
        }
    }
}
