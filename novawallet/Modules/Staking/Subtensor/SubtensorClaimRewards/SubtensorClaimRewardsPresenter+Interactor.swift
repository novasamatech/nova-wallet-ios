import Foundation
import Foundation_iOS

extension SubtensorClaimRewardsPresenter: SubtensorClaimInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        logger.debug("Fee: \(fee)")

        self.fee = fee

        provideViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        positionsState = state

        provideViewModel()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed

        provideViewModel()
    }

    func didReceiveClaimable(_ claimable: SubtensorRootClaimable?) {
        guard let claimable else {
            return
        }

        self.claimable = claimable

        provideViewModel()
    }

    func didReceiveBlockNumber(_: BlockNumber) {}

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        self.preflight = preflight

        provideViewModel()
    }

    func didReceiveQuote(_: SubtensorTradeQuote) {}

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        existentialDeposit = deposit
    }

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Error: \(error)")

        switch error {
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
            }
        case .preflightFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshPreflight()
            }
        case .quoteFailed:
            break
        }
    }

    func didReceiveClaimSnapshot(_ claimable: SubtensorRootClaimable) {
        handleClaimSnapshot(claimable)
    }

    func didFailClaimSnapshot(_ error: Error) {
        logger.error("Claim snapshot failed: \(error)")

        handleClaimSnapshotFailure()
    }
}

extension SubtensorClaimRewardsPresenter: SubtensorOperationResultDelegate {
    func didRequestRetry() {
        finishHandOff()

        refreshFee()
        refreshPreflight()
        interactor.refreshPositions()
        interactor.refreshClaimSnapshot()

        provideViewModel()
    }
}

extension SubtensorClaimRewardsPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else {
            return
        }

        provideAccountViewModels()
        provideViewModel()
    }
}
