import Foundation

extension SubtensorPositionPresenter: SubtensorPositionInteractorOutputProtocol {
    func didReceive(group: SubtensorPortfolioGroup?) {
        guard let group else {
            guard !isClosed else {
                return
            }

            isClosed = true
            wireframe.popToPortfolio(from: view)
            return
        }

        apply(group: group)
        provideViewModel()
    }

    func didReceiveSyncFailure(_ isFailed: Bool) {
        state.isSyncFailed = isFailed
        provideViewModel()
    }

    func didReceivePositionsSyncing(_ isSyncing: Bool) {
        if !isSyncing {
            view?.didCompleteRefreshing()
        }
    }

    func didReceive(price: PriceData?) {
        state.price = .loaded(price)
        provideViewModel()
    }

    func didChangeCurrency() {
        state.price = .loading
        provideViewModel()
    }

    func didReceive(prices: SubtensorAlphaPrices) {
        state.prices = prices
        resolveCatalogue()
    }

    func didFailPrices() {
        resolveCatalogue()
    }

    func didReceive(subnetsInfo: SubtensorSubnetsInfo?) {
        guard
            let subnet = subnetsInfo?.subnets.first(where: { $0.netuid == state.netuid }),
            let price = subnetsInfo?.prices[state.netuid] else {
            if isSubnetsRefreshForced {
                isSubnetsInfoUnavailable = true
            } else {
                isSubnetsRefreshForced = true
                interactor.loadSubnetsInfo()
            }

            return
        }

        target = .subnet(info: subnet, price: price)
    }

    func didReceive(subnetLogos: SubtensorSubnetLogos?) {
        state.subnetLogos = subnetLogos
        provideViewModel()
    }

    func didReceive(validator: SubtensorValidatorDirectoryItem?, for hotkey: AccountId) {
        guard hotkey == state.group?.primaryHotkey else {
            return
        }

        state.validatorHotkey = hotkey
        state.validator = validator
        provideViewModel()
    }

    func didFailValidator(for hotkey: AccountId) {
        guard hotkey == validatorRequest?.hotkey else {
            return
        }

        validatorRequest = nil
    }

    func didReceive(yields: SubtensorAlphaYields?) {
        state.isRateResolved = true
        state.yields = yields
        provideViewModel()
    }

    func didReceive(costBasis: SubtensorCostBasis?) {
        state.costBasis = costBasis.map { .resolved($0) } ?? .unavailable
        provideViewModel()
    }

    func didReceiveOwnTradeSettling(_ isSettling: Bool) {
        state.isOwnTradeSettling = isSettling
        provideViewModel()
    }

    func didReceive(claimable: [SubtensorRootClaimPreview], isFailed: Bool) {
        state.claimable = claimable
        state.isClaimableFailed = isFailed
        provideViewModel()
    }

    func didReceive(pendingClaimHotkeys: Set<AccountId>) {
        guard pendingClaimHotkeys != state.pendingClaimHotkeys else {
            return
        }

        state.pendingClaimHotkeys = pendingClaimHotkeys
        provideViewModel()
    }

    func didReceive(holds: [AccountId: SubtensorRootHold], blockTime: BlockTime?) {
        state.holds = holds
        state.blockTime = blockTime
        provideViewModel()
    }

    func didReceive(blockNumber: BlockNumber) {
        state.blockNumber = blockNumber
        provideViewModel()
    }

    func didReceive(history: SubtensorPriceHistory?, for period: SubtensorPricePeriod) {
        guard period == state.period else {
            return
        }

        state.chartEndDate = Date()
        state.history = history.map { .available($0) } ?? .notListed
        state.hasResolvedHistory = true
        provideViewModel()
    }

    func didFailHistory(for period: SubtensorPricePeriod, error: Error) {
        guard period == state.period, state.history == .loading else {
            return
        }

        dataAnalytics.trackFailure(error, endpoint: .coingecko)

        state.history = .failed
        state.hasResolvedHistory = true
        provideViewModel()
    }

    func didBecomeActive() {
        loadValidatorIfNeeded()
    }
}
