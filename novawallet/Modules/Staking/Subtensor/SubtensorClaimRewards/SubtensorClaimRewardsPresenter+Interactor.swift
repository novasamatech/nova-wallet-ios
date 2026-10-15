import Foundation
import Foundation_iOS

extension SubtensorClaimRewardsPresenter: SubtensorStakingBaseInteractorOutputProtocol {
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

        if let state, !state.isRootRedeemableStale {
            claimable = state.rootClaimPreviews
            applySilently(state.rootClaimPreviews)
        }

        provideViewModel()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed

        provideViewModel()
    }

    func didReceiveBlockNumber(_: BlockNumber) {}

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        self.preflight = preflight

        provideViewModel()
    }

    func didReceiveQuote(_: SubtensorTradeQuote) {}

    func didReceiveCatalogue(_: SubtensorSubnetCatalogue?) {}

    func didReceiveSubnetLogos(_: SubtensorSubnetLogos?) {}

    func didReceiveCostBasis(_: SubtensorCostBasis?) {}

    func didReceiveRootHolds(_: [AccountId: SubtensorRootHold]) {}

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        existentialDeposit = deposit
    }

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Error: \(error)")

        presentBaseRetry(for: error)
    }
}

extension SubtensorClaimRewardsPresenter: SubtensorOperationResultDelegate {
    func didRequestRetry() {
        finishHandOff()

        refreshFee()
        refreshPreflight()
        interactor.refreshPositions()

        provideViewModel()
    }
}

extension SubtensorClaimRewardsPresenter: SubtensorBaseRetrying {
    var retryView: ControllerBackedProtocol? { view }
    var retryWireframe: AlertPresentable & FeeRetryable & CommonRetryable { wireframe }
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
