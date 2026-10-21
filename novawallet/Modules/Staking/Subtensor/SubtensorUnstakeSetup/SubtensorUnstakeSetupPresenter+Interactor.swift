import Foundation

extension SubtensorUnstakeSetupPresenter {
    func applyBasisChange(from previousPlan: SubtensorUnstakePlan?) {
        if anchorHotkey != preflightRequest {
            preflight = nil
            refreshPreflight()
        }

        loadValidatorIfNeeded()
        loadValidatorsIfNeeded()
        loadGroupHotkeys()

        if isRoot, let group, !group.positions.isEmpty {
            interactor.loadRootHolds(for: group.positions.map(\.hotkey))
        }

        if case .rate = inputResult, feePlan()?.amount != previousPlan?.amount {
            provideAmountInputViewModel()
        }

        refreshFee()
        updateQuote()
    }

    func loadValidatorsIfNeeded() {
        guard let group, group.positions.count > 1, let subnetRef else {
            return
        }

        let hotkeys = group.positions.map(\.hotkey)

        guard hotkeys != validatorsRequest else {
            return
        }

        validatorsRequest = hotkeys
        interactor.loadValidators(hotkeys, on: subnetRef)
    }
}

private extension SubtensorUnstakeSetupPresenter {
    func findGroup(in state: Multistaking.SubtensorState?) -> SubtensorPortfolioGroup? {
        state.flatMap { SubtensorPortfolioBuilder.build(state: $0).group(netuid: netuid) }
    }

    func presentSubnetRetry(tracksRetry: Bool) {
        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            guard let self else {
                return
            }

            if tracksRetry {
                dataAnalytics.trackRetry(.chainRpc)
            }

            interactor.loadSubnetsInfo(for: netuid)
        }
    }
}

extension SubtensorUnstakeSetupPresenter: SubtensorUnstakeSetupInteractorOutputProtocol {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo) {
        guard !isRoot else {
            return
        }

        guard
            let subnetInfo = info.subnets.first(where: { $0.netuid == netuid }),
            let subnetPrice = info.prices[netuid] else {
            guard !isSubnetsRefreshForced else {
                presentSubnetRetry(tracksRetry: false)
                return
            }

            isSubnetsRefreshForced = true
            interactor.loadSubnetsInfo(for: netuid)
            return
        }

        let previousPlan = feePlan()

        target = .subnet(info: subnetInfo, price: subnetPrice)

        loadValidatorIfNeeded()
        loadValidatorsIfNeeded()

        if case .rate = inputResult, feePlan()?.amount != previousPlan?.amount {
            provideAmountInputViewModel()
        }

        refreshFee()
        updateQuote()
        provideViewModel()
    }

    func didReceiveSubnetsInfoError(_ error: Error) {
        logger.error("Subtensor unstake subnets info failed: \(error)")
        dataAnalytics.trackFailure(error, endpoint: .chainRpc)

        presentSubnetRetry(tracksRetry: true)
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

    func didReceiveNovaFeeRate(_ rate: BigRational?) {
        novaFeeRate = rate
    }

    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, hotkey: AccountId) {
        guard hotkey == anchorHotkey else {
            return
        }

        validatorItem = validator

        provideViewModel()
    }

    func didReceiveValidators(_ validators: [AccountId: SubtensorValidatorDirectoryItem], hotkeys: [AccountId]) {
        guard hotkeys == validatorsRequest else {
            return
        }

        validatorItems = validators
    }

    func didFailValidators(for hotkeys: [AccountId]) {
        guard hotkeys == validatorsRequest else {
            return
        }

        validatorsRequest = nil
    }

    func didReceiveGroupHotkeys(_ info: [AccountId: SubtensorGroupHotkeyInfo]) {
        let previousPlan = feePlan()

        groupHotkeys = info

        applyPlanChange(from: previousPlan)
        provideViewModel()
    }

    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold]) {
        let previousPlan = feePlan()

        self.holds = holds

        applyPlanChange(from: previousPlan)
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

    func didReceivePositions(_ state: Multistaking.SubtensorState?) {
        let previousBasis = basis
        let previousPlan = feePlan()

        positionsState = state
        group = findGroup(in: state)

        if basis != previousBasis {
            applyBasisChange(from: previousPlan)
        }

        provideViewModel()
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed
    }

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        let previousPlan = feePlan()

        currentBlock = blockNumber

        if isRoot {
            applyPlanChange(from: previousPlan)
        } else if !isConfirmationShown {
            forceQuoteRefresh()
        }

        provideViewModel()
    }

    func didReceivePreflight(_ preflight: SubtensorPreflight) {
        let previousPlan = feePlan()

        self.preflight = preflight
        blockTime = preflight.blockTime

        applyPlanChange(from: previousPlan)
        provideViewModel()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        existentialDeposit = deposit
    }
}
