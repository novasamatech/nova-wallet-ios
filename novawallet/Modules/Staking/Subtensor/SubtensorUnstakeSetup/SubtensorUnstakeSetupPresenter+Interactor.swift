import Foundation

extension SubtensorUnstakeSetupPresenter {
    func reloadGroupData() {
        loadValidatorsIfNeeded()
        loadGroupHotkeys()

        if isRoot, let group, !group.positions.isEmpty {
            interactor.loadRootHolds(for: group.positions.map(\.hotkey))
        }
    }

    func applyBasisChange(from previousPlan: SubtensorUnstakePlan?) {
        reconcileAnchor()

        if case .rate = inputResult, feePlan()?.amount != previousPlan?.amount {
            provideAmountInputViewModel()
        }

        refreshFee()
        updateQuote()
    }

    func reconcileAnchor() {
        if anchorHotkey != preflightRequest {
            preflight = nil
            refreshPreflight()
        }

        loadValidatorIfNeeded()
    }

    func loadValidatorsIfNeeded() {
        guard let group, let subnetRef else {
            return
        }

        let hotkeys = group.positions.map(\.hotkey)

        guard !hotkeys.isEmpty, hotkeys != validatorsRequest else {
            return
        }

        validatorsRequest = hotkeys
        interactor.loadValidators(hotkeys, on: subnetRef)
    }

    func retryValidatorNames() {
        failedValidatorRequest = nil

        loadValidatorsIfNeeded()
        loadValidatorIfNeeded()
    }

    func loadValidatorIfNeeded() {
        guard
            let anchorHotkey,
            validatorItems[anchorHotkey] == nil,
            anchorHotkey != validatorRequest,
            anchorHotkey != failedValidatorRequest,
            validatorsRequest == validatorsResolved,
            let subnetRef else {
            return
        }

        validatorRequest = anchorHotkey
        interactor.loadValidator(anchorHotkey, on: subnetRef)
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

        loadValidatorsIfNeeded()
        loadValidatorIfNeeded()

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
        if validator == nil, hotkey == validatorRequest {
            validatorRequest = nil
            failedValidatorRequest = hotkey
        }

        validatorItems[hotkey] = validator ?? validatorItems[hotkey]

        refreshValidatorPicker()
        provideViewModel()
    }

    func didReceiveValidators(_ validators: [AccountId: SubtensorValidatorDirectoryItem], hotkeys: [AccountId]) {
        guard hotkeys == validatorsRequest else {
            return
        }

        validatorItems.merge(validators) { _, new in new }
        validatorsResolved = hotkeys

        loadValidatorIfNeeded()
        refreshValidatorPicker()
        provideViewModel()
    }

    func didFailValidators(for hotkeys: [AccountId]) {
        guard hotkeys == validatorsRequest else {
            return
        }

        validatorsRequest = nil
        validatorsResolved = nil

        loadValidatorIfNeeded()
    }

    func didReceiveGroupHotkeys(_ info: [AccountId: SubtensorGroupHotkeyInfo]) {
        let previousPlan = feePlan()

        groupHotkeys = info

        applyPlanChange(from: previousPlan)
        refreshValidatorPicker()
        provideViewModel()
    }

    func didReceiveRootHolds(_ holds: [AccountId: SubtensorRootHold]) {
        let previousPlan = feePlan()

        self.holds = holds

        applyPlanChange(from: previousPlan)
        refreshValidatorPicker()
        provideViewModel()
    }

    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?) {
        self.costBasis = costBasis.map { .resolved($0) } ?? .unavailable

        provideViewModel()
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance

        refreshShieldQuote(for: shieldQuoteOperation, plan: shieldQuoteInputs?.plan)
        provideViewModel()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        provideViewModel()
    }

    func didReceiveShieldQuote(_ quote: SubtensorShieldQuote?) {
        shieldQuote = quote
        isShieldQuoteResolved = true

        provideViewModel()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorState?) {
        let previousPositions = group?.positions
        let previousBasis = basis
        let previousPlan = feePlan()

        positionsState = state
        group = findGroup(in: state)

        if group?.positions != previousPositions {
            reloadGroupData()
        }

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

        retryUnresolvedShieldQuote()
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

        provideViewModel()
    }
}
