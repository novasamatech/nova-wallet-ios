import Foundation
import SoraFoundation
import BigInt

final class GovernanceUnlockSetupPresenter {
    weak var view: GovernanceUnlockSetupViewProtocol?
    let wireframe: GovernanceUnlockSetupWireframeProtocol
    let interactor: GovernanceUnlockSetupInteractorInputProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let assetDisplayInfo: AssetBalanceDisplayInfo
    let logger: LoggerProtocol

    private var votingResult: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>?
    private var unlockSchedule: GovernanceUnlockSchedule?
    private var blockNumber: BlockNumber?
    private var blockTime: BlockTime?
    private var price: PriceData?

    private var maxStatusTimeInterval: TimeInterval?
    private var countdownTimer: CountdownTimer?

    init(
        interactor: GovernanceUnlockSetupInteractorInputProtocol,
        wireframe: GovernanceUnlockSetupWireframeProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.balanceViewModelFactory = balanceViewModelFactory
        self.assetDisplayInfo = assetDisplayInfo
        self.logger = logger
        self.localizationManager = localizationManager
    }

    deinit {
        invalidateTimer()
    }

    private func createTotalBalanceViewModel(for amount: BigUInt) -> BalanceViewModelProtocol {
        let decimalAmount = Decimal.fromSubstrateAmount(amount, precision: assetDisplayInfo.assetPrecision) ?? 0
        return balanceViewModelFactory.balanceFromPrice(decimalAmount, priceData: price).value(for: selectedLocale)
    }

    private func calculateMaxUnlockTimeInterval(
        block: BlockNumber,
        blockTime: BlockTime
    ) -> TimeInterval? {
        let intervals: [TimeInterval] = (unlockSchedule?.items ?? []).compactMap { item in
            if block < item.unlockAt {
                return block.secondsTo(block: item.unlockAt, blockDuration: blockTime)
            } else {
                return nil
            }
        }

        return intervals.max()
    }

    private func createUnlockClaimState(
        for unlockAt: BlockNumber,
        block: BlockNumber,
        blockTime: BlockTime,
        elapsedTimeInterval: TimeInterval?
    ) -> GovernanceUnlocksViewModel.ClaimState {
        if block < unlockAt {
            let remainedTimeInSeconds = block.secondsTo(block: unlockAt, blockDuration: blockTime)

            let tickedTime: TimeInterval

            if let elapsedTimeInterval = elapsedTimeInterval {
                tickedTime = remainedTimeInSeconds > elapsedTimeInterval ?
                    remainedTimeInSeconds - elapsedTimeInterval : 0
            } else {
                tickedTime = remainedTimeInSeconds
            }

            if let leftTime = tickedTime.localizedDaysOrTime(for: selectedLocale) {
                let time = R.string.localizable.commonTimeLeftFormat(
                    leftTime,
                    preferredLanguages: selectedLocale.rLanguages
                )

                return .afterPeriod(time: time)
            } else {
                return .afterPeriod(time: "")
            }

        } else {
            return .now
        }
    }

    private func createClaimableViewModel(for amount: BigUInt) -> GovernanceUnlocksViewModel.Item {
        let amountDecimal = Decimal.fromSubstrateAmount(
            amount,
            precision: assetDisplayInfo.assetPrecision
        ) ?? 0

        let amountString = balanceViewModelFactory.amountFromValue(amountDecimal).value(for: selectedLocale)

        return .init(amount: amountString, claimState: .now)
    }

    private func createUnlockViewModel(
        for amount: BigUInt,
        unlockAt: BlockNumber,
        block: BlockNumber,
        blockTime: BlockTime
    ) -> GovernanceUnlocksViewModel.Item {
        let amountDecimal = Decimal.fromSubstrateAmount(
            amount,
            precision: assetDisplayInfo.assetPrecision
        ) ?? 0

        let amountString = balanceViewModelFactory.amountFromValue(amountDecimal).value(for: selectedLocale)

        let claimState = createUnlockClaimState(
            for: unlockAt,
            block: block,
            blockTime: blockTime,
            elapsedTimeInterval: nil
        )

        return .init(amount: amountString, claimState: claimState)
    }

    private func updateView() {
        guard
            let blockNumber = blockNumber,
            let blockTime = blockTime,
            let tracksVoting = votingResult?.value else {
            return
        }

        let totalViewModel = createTotalBalanceViewModel(for: tracksVoting.totalLocked())

        let items: [GovernanceUnlocksViewModel.Item]

        if let unlockSchedule = unlockSchedule {
            let availableUnlock = unlockSchedule.availableUnlock(at: blockNumber)

            let remainingUnlocks = unlockSchedule.remainingLocks(after: blockNumber)

            let remainingUnlockViewModels = remainingUnlocks.map {
                createUnlockViewModel(
                    for: $0.amount,
                    unlockAt: $0.unlockAt,
                    block: blockNumber,
                    blockTime: blockTime
                )
            }

            if !availableUnlock.isEmpty {
                let availableUnlockViewModel = createClaimableViewModel(for: availableUnlock.amount)
                items = [availableUnlockViewModel] + remainingUnlockViewModels
            } else {
                items = remainingUnlockViewModels
            }
        } else {
            items = []
        }

        view?.didReceive(viewModel: .init(total: totalViewModel, items: items))
    }

    private func refreshUnlockSchedule() {
        guard let tracksVoting = votingResult?.value else {
            return
        }

        interactor.refreshUnlockSchedule(for: tracksVoting, blockHash: nil)
    }

    private func invalidateTimer() {
        countdownTimer?.delegate = self
        countdownTimer?.stop()
        countdownTimer = nil
    }

    private func setupTimerIfNeeded() {
        invalidateTimer()

        guard
            let blockNumber = blockNumber,
            let blockTime = blockTime else {
            return
        }

        guard let maxTimeInterval = calculateMaxUnlockTimeInterval(block: blockNumber, blockTime: blockTime) else {
            return
        }

        maxStatusTimeInterval = maxTimeInterval

        countdownTimer = CountdownTimer()
        countdownTimer?.delegate = self
        countdownTimer?.start(with: maxTimeInterval)
    }

    private func updateViewOnTimerTick() {
        guard
            let maxStatusTimeInterval = maxStatusTimeInterval,
            let remainedInterval = countdownTimer?.remainedInterval,
            let blockNumber = blockNumber,
            let blockTime = blockTime else {
            return
        }

        let elapsedTimeInterval = maxStatusTimeInterval - remainedInterval

        let items: [GovernanceUnlocksViewModel.ClaimState]

        if let unlockSchedule = unlockSchedule {
            let availableUnlock = unlockSchedule.availableUnlock(at: blockNumber)

            let remainingUnlocks = unlockSchedule.remainingLocks(after: blockNumber).map {
                createUnlockClaimState(
                    for: $0.unlockAt,
                    block: blockNumber,
                    blockTime: blockTime,
                    elapsedTimeInterval: elapsedTimeInterval
                )
            }

            if !availableUnlock.isEmpty {
                items = [.now] + remainingUnlocks
            } else {
                items = remainingUnlocks
            }
        } else {
            items = []
        }

        view?.didTickClaim(states: items)
    }
}

extension GovernanceUnlockSetupPresenter: GovernanceUnlockSetupPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func unlock() {
        guard
            let votingResult = votingResult,
            let unlockSchedule = unlockSchedule,
            let blockNumber = blockNumber else {
            return
        }

        wireframe.showConfirm(
            from: view,
            votingResult: votingResult,
            schedule: unlockSchedule,
            blockNumber: blockNumber
        )
    }
}

extension GovernanceUnlockSetupPresenter: GovernanceUnlockSetupInteractorOutputProtocol {
    func didReceiveVoting(_ result: CallbackStorageSubscriptionResult<ReferendumTracksVotingDistribution>) {
        votingResult = result

        updateView()

        if let tracksVoting = result.value {
            interactor.refreshUnlockSchedule(for: tracksVoting, blockHash: result.blockHash)
        }
    }

    func didReceiveUnlockSchedule(_ schedule: GovernanceUnlockSchedule) {
        unlockSchedule = schedule

        updateView()
    }

    func didReceiveBlockNumber(_ block: BlockNumber) {
        blockNumber = block

        updateView()

        interactor.refreshBlockTime()

        refreshUnlockSchedule()
    }

    func didReceiveBlockTime(_ time: BlockTime) {
        blockTime = time

        updateView()

        setupTimerIfNeeded()
    }

    func didReceivePrice(_ price: PriceData?) {
        self.price = price

        updateView()
    }

    func didReceiveBaseError(_ error: GovernanceUnlockInteractorError) {
        logger.error("Did receive error: \(error)")

        switch error {
        case .votingSubscriptionFailed, .priceSubscriptionFailed, .blockNumberSubscriptionFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.remakeSubscriptions()
            }
        case .unlockScheduleFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.refreshUnlockSchedule()
            }
        case .blockTimeFetchFailed:
            wireframe.presentRequestStatus(on: view, locale: selectedLocale) { [weak self] in
                self?.interactor.refreshBlockTime()
            }
        }
    }
}

extension GovernanceUnlockSetupPresenter: CountdownTimerDelegate {
    func didStart(with _: TimeInterval) {
        updateViewOnTimerTick()
    }

    func didCountdown(remainedInterval _: TimeInterval) {
        updateViewOnTimerTick()
    }

    func didStop(with _: TimeInterval) {
        updateViewOnTimerTick()
    }
}

extension GovernanceUnlockSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
