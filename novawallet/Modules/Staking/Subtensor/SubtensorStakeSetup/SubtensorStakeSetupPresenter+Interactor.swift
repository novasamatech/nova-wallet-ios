import Foundation

extension SubtensorStakeSetupPresenter: SubtensorStakeSetupInteractorOutputProtocol {
    func didReceiveValidator(_ validator: SubtensorValidatorDirectoryItem?, on subnet: SubtensorSubnetRef) {
        guard subnet == subnetRef else {
            return
        }

        if let lockedHotkey = mode.lockedHotkey {
            if let validator, validator.hotkey == lockedHotkey {
                validatorState = .selected(SubtensorStakeSetupValidator(hotkey: lockedHotkey, name: validator.name))
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

    func didFailValidator(_ error: Error, on subnet: SubtensorSubnetRef) {
        guard subnet == subnetRef, mode.lockedHotkey == nil, case .pending = validatorState else {
            return
        }

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

        wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
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

    func didReceivePositions(_ state: Multistaking.SubtensorState?) {
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

    func didReceiveBlockNumber(_: BlockNumber) {
        guard !isConfirmationShown else {
            return
        }

        forceQuoteRefresh()
    }

    func didReceivePreflight(_ preflight: SubtensorPreflight) {
        self.preflight = preflight
    }

    func didReceiveBlockTime(_ blockTime: BlockTime) {
        self.blockTime = blockTime
        provideViewModel()
    }

    func didReceiveExistentialDeposit(_: Balance) {}
}
