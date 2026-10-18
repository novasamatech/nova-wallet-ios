import Foundation

private extension SubtensorUnstakeSetupPresenter {
    func findGroup(in state: Multistaking.SubtensorStakingState?) -> SubtensorPortfolioGroup? {
        state.flatMap { SubtensorPortfolioBuilder.build(state: $0).group(netuid: netuid) }
    }

    func applyBasisChange(from previousAmount: Balance?) {
        if group?.primaryHotkey != preflightRequest {
            preflight = nil
            refreshPreflight()
        }

        loadValidatorIfNeeded()

        if isRoot, let group, !group.positions.isEmpty {
            interactor.loadRootHolds(for: group.positions.map(\.hotkey))
        }

        if case .rate = inputResult, inputAmount() != previousAmount {
            provideAmountInputViewModel()
        }

        refreshFee()
        updateQuote()
    }

    func presentSubnetRetry() {
        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.interactor.loadSubnetsInfo()
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
            interactor.loadSubnetsInfo()
            return
        }

        let previousAmount = inputAmount()

        target = .subnet(info: subnetInfo, price: subnetPrice)

        loadValidatorIfNeeded()

        if case .rate = inputResult, inputAmount() != previousAmount {
            provideAmountInputViewModel()
        }

        refreshFee()
        updateQuote()
        provideViewModel()
    }

    func didReceiveSubnetsInfoError(_ error: Error) {
        logger.error("Subtensor unstake subnets info failed: \(error)")

        presentSubnetRetry()
    }

    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?) {
        self.catalogue = catalogue

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
        let previousAmount = inputAmount()

        self.holds = holds

        applyAmountChange(from: previousAmount)
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
        let previousAmount = inputAmount()

        positionsState = state
        group = findGroup(in: state)

        if basis != previousBasis {
            applyBasisChange(from: previousAmount)
        }

        provideViewModel()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        let previousAmount = inputAmount()

        currentBlock = blockNumber

        if isRoot {
            applyAmountChange(from: previousAmount)
        } else {
            forceQuoteRefresh()
        }

        provideViewModel()
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        let previousAmount = inputAmount()

        self.preflight = preflight
        blockTime = preflight.blockTime

        applyAmountChange(from: previousAmount)
        provideViewModel()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        existentialDeposit = deposit
    }
}
