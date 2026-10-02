import Foundation

private extension SubtensorUnstakeSetupPresenter {
    func findGroup(in state: Multistaking.SubtensorStakingState?) -> SubtensorPortfolioGroup? {
        guard let state else {
            return nil
        }

        let portfolio = SubtensorPortfolioBuilder.build(state: state)

        return isRoot ? portfolio.root : portfolio.subnets.first { $0.netuid == netuid }
    }

    func applyMaxChange(from previousMax: Balance?) {
        guard case .rate = inputResult, maxAmount != previousMax else {
            return
        }

        provideAmountInputViewModel()
        refreshFee()
        updateQuote()
    }

    func applyBasisChange(from previousMax: Balance?) {
        if group?.primaryHotkey != preflightRequest {
            preflight = nil
            refreshPreflight()
        }

        loadValidatorIfNeeded()

        if isRoot, let basis, !basis.hotkeys.isEmpty {
            interactor.loadRootHolds(for: basis.hotkeys)
        }

        if case .rate = inputResult, maxAmount != previousMax {
            provideAmountInputViewModel()
        }

        refreshFee()
        updateQuote()
    }

    func presentSubnetRetry() {
        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.interactor.loadSubnetsInfo(forcingRefresh: true)
        }
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeInteractorOutputProtocol {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo) {
        guard !isRoot else {
            return
        }

        guard
            let subnetInfo = info.subnets.first(where: { $0.netuid == netuid }),
            let subnetPrice = info.prices[netuid] else {
            guard !isSubnetsRefreshForced else {
                presentSubnetRetry()
                return
            }

            isSubnetsRefreshForced = true
            interactor.loadSubnetsInfo(forcingRefresh: true)
            return
        }

        target = .subnet(info: subnetInfo, price: subnetPrice)

        loadValidatorIfNeeded()
        refreshFee()
        updateQuote()
        provideViewModel()
    }

    func didReceiveSubnetsInfoError(_ error: Error) {
        logger.error("Subtensor unstake subnets info failed: \(error)")

        presentSubnetRetry()
    }

    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?) {
        guard catalogue != nil || self.catalogue?.subnet(for: netuid) == nil else {
            return
        }

        self.catalogue = catalogue

        if !isRoot, let catalogue, catalogue.subnet(for: netuid) == nil, !isCatalogueRefreshForced {
            isCatalogueRefreshForced = true
            interactor.loadCatalogue()
        }

        provideAssetViewModel()
        provideViewModel()
    }

    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?) {
        subnetLogos = logos

        provideAssetViewModel()
    }

    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, hotkey: AccountId) {
        guard hotkey == group?.primaryHotkey else {
            return
        }

        validatorItem = validator

        provideViewModel()
    }

    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold]) {
        let previousMax = maxAmount

        self.holds = holds

        applyMaxChange(from: previousMax)
        provideViewModel()
    }

    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?) {
        self.costBasis = costBasis.map { .resolved($0) } ?? .unavailable

        provideViewModel()
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        provideViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        let previousBasis = basis
        let previousMax = maxAmount

        positionsState = state
        group = findGroup(in: state)

        if basis != previousBasis {
            applyBasisChange(from: previousMax)
        }

        provideViewModel()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed
    }

    func didReceiveClaimable(_: SubtensorRootClaimable?) {}

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        let previousMax = maxAmount

        currentBlock = blockNumber

        if isRoot {
            applyMaxChange(from: previousMax)
        } else {
            forceQuoteRefresh()
        }

        provideViewModel()
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        self.preflight = preflight
    }

    func didReceiveQuote(_ quote: SubtensorTradeQuote) {
        guard quoteFlow.applyQuote(quote) else {
            return
        }

        tradesUnavailable = false
        isQuoteFailed = false

        provideViewModel()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        existentialDeposit = deposit
    }

    func didReceiveBaseError(_ error: SubtensorStakingBaseError) {
        logger.error("Subtensor unstake setup error: \(error)")

        if error.isNovaFeeUnavailable {
            tradesUnavailable = true
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
            quoteFlow.clearQuote()
            isQuoteFailed = true
            provideViewModel()
        }
    }
}
