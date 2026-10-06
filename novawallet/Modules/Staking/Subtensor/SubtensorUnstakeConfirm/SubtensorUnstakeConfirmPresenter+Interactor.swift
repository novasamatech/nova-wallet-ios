import Foundation
import Foundation_iOS

extension SubtensorUnstakeConfirmPresenter {
    func seedSubnetData() {
        guard !model.target.isRoot else {
            return
        }

        if let catalogue = interactor.cachedCatalogue().value, catalogue.subnet(for: unstakeModel.netuid) != nil {
            self.catalogue = catalogue
        }

        if case let .fresh(costBasis, _) = interactor.cachedCostBasis(netuid: unstakeModel.netuid) {
            self.costBasis = .resolved(costBasis)
        }
    }

    func loadCostBasisIfNeeded() {
        guard costBasis == .loading else {
            return
        }

        interactor.loadCostBasis(for: unstakeModel.netuid)
    }
}

extension SubtensorUnstakeConfirmPresenter: SubtensorUnstakeConfirmOutputProtocol {
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

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        positionsState = state

        provideViewModel()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed

        provideViewModel()
    }

    func didReceiveClaimable(_: SubtensorRootClaimable?) {}

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        currentBlock = blockNumber

        guard !isHandingOff else {
            return
        }

        refreshQuote()
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
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

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Error: \(error)")

        guard !error.isNovaFeeUnavailable else {
            tradesUnavailable = true
            quoteState?.invalidateLatest()
            provideViewModel()
            return
        }

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
            quoteState?.markLatestFailed()
            provideViewModel()
        }
    }

    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?) {
        guard catalogue != nil || self.catalogue?.subnet(for: unstakeModel.netuid) == nil else {
            return
        }

        self.catalogue = catalogue

        provideTileIcons()
        provideViewModel()
    }

    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?) {
        subnetLogos = logos

        provideTileIcons()
    }

    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold]) {
        self.holds = holds
    }

    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?) {
        self.costBasis = costBasis.map { .resolved($0) } ?? .unavailable

        provideViewModel()
    }
}

extension SubtensorUnstakeConfirmPresenter: SubtensorOperationResultDelegate {
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

extension SubtensorUnstakeConfirmPresenter: Localizable {
    func applyLocalization() {
        guard let view, view.isSetup else {
            return
        }

        provideAccountViewModels()
        provideViewModel()
    }
}
