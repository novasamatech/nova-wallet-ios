import Foundation

extension SubtensorStakingSetupPresenter: SubtensorSetupInteractorOutputProtocol {
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, on subnet: SubtensorSubnetRef) {
        guard subnet == subnetRef else {
            return
        }

        if let lockedHotkey = mode.lockedHotkey {
            if let validator, validator.hotkey == lockedHotkey {
                validatorState = .selected(SubtensorSetupValidator(hotkey: lockedHotkey, name: validator.name))
                validatorItem = validator
                provideViewModel()
            }

            return
        }

        guard case .pending = validatorState else {
            return
        }

        if let validator {
            applyValidator(validator)
        } else {
            validatorState = .none
            provideViewModel()
        }
    }

    func didReceiveRootYield(_ yield: SubtensorReportedYield?) {
        rootRate = SubtensorAlphaApyFormatter.annualRate(from: yield)
        isRootRateLoaded = true

        provideViewModel()
    }

    func didReceiveSubnet(_ target: SubtensorStakeTarget) {
        guard case let .buyMore(position) = mode, self.target == nil, target.netuid == position.netuid else {
            return
        }

        self.target = target

        applyTargetIfReady()
    }

    func didFailSubnet(_ error: Error) {
        logger.error("Subtensor setup subnet failed: \(error)")

        guard case let .buyMore(position) = mode else {
            return
        }

        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.interactor.loadSubnet(netuid: position.netuid)
        }
    }

    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?) {
        self.catalogue = catalogue
        isCatalogueLoaded = true

        provideViewModel()
    }

    func didReceiveYields(_ yields: SubtensorAlphaYields?, netuid: UInt16) {
        guard netuid == yieldsNetuid else {
            return
        }

        self.yields = yields
        isYieldsLoaded = true

        provideViewModel()
    }

    func didReceiveRankingView(_ rankingView: SubtensorRankedSubnets?) {
        self.rankingView = rankingView

        provideViewModel()
    }

    func didReceiveEarnConfig(_ config: SubtensorEarnConfig?) {
        earnConfig = config

        provideViewModel()
    }

    func didReceiveAssetBalance(_ balance: AssetBalance?) {
        self.balance = balance
        isBalanceLoaded = true

        applyMaxChange()
    }

    func didReceivePrice(_ priceData: PriceData?) {
        price = priceData

        provideAssetViewModel()
        provideViewModel()
    }

    func didReceiveFee(_ fee: ExtrinsicFeeProtocol) {
        self.fee = fee

        applyMaxChange()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorStakingState?) {
        positionsState = state

        requestPresetIfReady()

        if case .addStake = mode {
            provideViewModel()
        }
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed

        requestPresetIfReady()
    }

    func didReceiveClaimable(_: SubtensorRootClaimable?) {}

    func didReceiveBlockNumber(_ blockNumber: BlockNumber) {
        currentBlock = blockNumber

        forceQuoteRefresh()

        if case .addStake = mode {
            provideViewModel()
        }
    }

    func didReceivePreflight(_ preflight: SubtensorStakingPreflight) {
        self.preflight = preflight

        if case .addStake = mode {
            provideViewModel()
        }
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
        logger.error("Subtensor setup error: \(error)")

        if error.isNovaFeeUnavailable {
            tradesUnavailable = true
        }

        switch error {
        case .feeFailed:
            wireframe.presentFeeStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshFee(resetting: false)
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
