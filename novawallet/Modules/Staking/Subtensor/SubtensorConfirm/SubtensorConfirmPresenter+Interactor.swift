import Foundation
import Foundation_iOS

extension SubtensorConfirmPresenter {
    func loadCostBasisIfNeeded() {
        guard tracksCostBasis else {
            return
        }

        interactor.loadCostBasis(for: model.target.netuid)
    }
}

extension SubtensorConfirmPresenter: SubtensorBaseInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance

        provideViewModel()
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

    func didReceivePositions(_ state: Multistaking.SubtensorState?) {
        positionsState = state

        provideViewModel()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed

        provideViewModel()
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        currentBlock = blockNumber

        guard !isHandingOff else {
            return
        }

        refreshQuote()
    }

    func didReceivePreflight(_ preflight: SubtensorPreflight) {
        self.preflight = preflight
    }

    func didReceiveQuote(_ quote: SubtensorTradeQuote) {
        guard var state = quoteState else {
            return
        }

        let hadAcknowledged = state.acknowledged != nil

        guard state.apply(latest: quote) else {
            return
        }

        quoteState = state
        tradesUnavailable = false

        if !hadAcknowledged {
            refreshFee()
        }

        provideViewModel()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        existentialDeposit = deposit

        provideViewModel()
    }

    func didReceiveBaseError(_ error: SubtensorBaseError) {
        logger.error("Error: \(error)")
        analytics.data.trackFailure(error)

        guard !error.isNovaFeeUnavailable else {
            tradesUnavailable = true
            quoteState?.invalidateLatest()
            provideViewModel()
            return
        }

        guard case .quoteFailed = error else {
            presentBaseRetry(for: error)
            return
        }

        quoteState?.markLatestFailed()
        provideViewModel()
    }

    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?) {
        self.catalogue = catalogue

        provideTileIcons()
        provideViewModel()
    }

    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?) {
        subnetLogos = logos

        provideTileIcons()
    }

    func didReceiveNovaFeeRate(_: BigRational?) {}

    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?) {
        self.costBasis = costBasis.map { .resolved($0) } ?? .unavailable

        provideViewModel()
    }
}

extension SubtensorConfirmPresenter: SubtensorOperationResultDelegate {
    func didRequestRetry() {
        finishHandOff()

        refreshQuote()
        refreshFee()
        refreshPreflight()
        refreshHolds()
        interactor.refreshPositions()

        provideViewModel()
    }
}

extension SubtensorConfirmPresenter: SubtensorBaseRetrying {
    var retryView: ControllerBackedProtocol? { view }
    var retryWireframe: AlertPresentable & FeeRetryable & CommonRetryable { wireframe }
    var retryInteractor: SubtensorBaseInteractorInputProtocol { interactor }
}

extension SubtensorConfirmPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else {
            return
        }

        provideAccountViewModels()
        provideViewModel()
    }
}
