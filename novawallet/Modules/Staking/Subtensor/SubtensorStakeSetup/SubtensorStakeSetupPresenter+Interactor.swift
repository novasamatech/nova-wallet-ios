import Foundation

extension SubtensorStakeSetupPresenter: SubtensorStakeSetupInteractorOutputProtocol {
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, on subnet: SubtensorSubnetRef) {
        guard subnet == subnetRef else {
            return
        }

        if mode.isLocked {
            let requested = lockedValidatorRequest
            lockedValidatorRequest = nil

            if let validator, validator.hotkey == requested {
                validatorItems[validator.hotkey] = validator
            }

            guard let requested, requested == mode.lockedHotkey else {
                return
            }

            isLockedValidatorPending = false
            validatorState = .selected(
                SubtensorStakeSetupValidator(hotkey: requested, name: validatorItems[requested]?.name)
            )
            refreshValidatorPicker()
            provideViewModel()
            return
        }

        guard case .pending = validatorState else {
            return
        }

        if let validator {
            recommendedHotkey = validator.hotkey
            applyValidator(validator)
        } else {
            validatorState = .none
            provideViewModel()
        }
    }

    func didFailValidator(_ error: Error, on subnet: SubtensorSubnetRef) {
        if mode.isLocked, lockedValidatorRequest != nil {
            lockedValidatorRequest = nil
            isLockedValidatorPending = false
            provideViewModel()
            return
        }

        guard subnet == subnetRef, mode.lockedHotkey == nil, case .pending = validatorState else {
            return
        }

        dataAnalytics.trackFailure(error, endpoint: .recommendations)
        presetError = error
        validatorState = .none
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

        dataAnalytics.trackFailure(error, endpoint: .chainRpc)
        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
            self?.dataAnalytics.trackRetry(.chainRpc)
            self?.interactor.loadSubnet(netuid: position.netuid)
        }
    }

    func didReceiveCatalogue(_ catalogue: SubtensorSubnetCatalogue?) {
        self.catalogue = catalogue

        provideViewModel()
    }

    func didReceiveYields(_ yields: SubtensorAlphaYields?, netuid: UInt16) {
        guard netuid == yieldsNetuid else {
            return
        }

        self.yields = yields
        isYieldsResolved = true

        provideViewModel()
    }

    func didReceiveRankingView(_ rankingView: SubtensorRankedSubnets?) {
        self.rankingView = rankingView

        provideViewModel()
    }

    func didReceiveSubnetLogos(_ logos: SubtensorSubnetLogos?) {
        subnetLogos = logos

        provideViewModel()
    }

    func didReceiveNovaFeeRate(_ rate: BigRational?) {
        novaFeeRate = rate
    }

    func didReceiveCostBasis(_ costBasis: SubtensorCostBasis?) {
        self.costBasis = costBasis.map { .resolved($0) } ?? .unavailable

        provideViewModel()
    }

    func didReceiveRootHolds(_: [AccountId: SubtensorRootHold]) {}

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

    func didReceiveShieldQuote(_ quote: SubtensorShieldQuote?) {
        shieldQuote = quote
        isShieldQuoteResolved = true

        applyMaxChange()
    }

    func didReceivePositions(_ state: Multistaking.SubtensorState?) {
        positionsState = state

        requestPresetIfReady()
        loadHeldValidatorsIfNeeded()

        if case .addStake = mode {
            provideViewModel()
        }
    }

    func didReceivePositionsSyncFailed(_ isFailed: Bool) {
        isPositionsSyncFailed = isFailed

        requestPresetIfReady()
    }

    func didReceiveBlockNumber(_: BlockNumber) {
        guard !isConfirmationShown else {
            return
        }

        forceQuoteRefresh()
        retryUnresolvedShieldQuote()
    }

    func didReceivePreflight(_ preflight: SubtensorPreflight) {
        self.preflight = preflight
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime
        provideViewModel()
    }

    func didReceiveExistentialDeposit(_ deposit: Balance) {
        existentialDeposit = deposit

        applyMaxChange()
    }
}
