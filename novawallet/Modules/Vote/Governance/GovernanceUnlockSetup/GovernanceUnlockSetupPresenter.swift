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

    private func createTotalBalanceViewModel(for amount: BigUInt) -> BalanceViewModelProtocol {
        let decimalAmount = Decimal.fromSubstrateAmount(amount, precision: assetDisplayInfo.assetPrecision) ?? 0
        return balanceViewModelFactory.balanceFromPrice(decimalAmount, priceData: price).value(for: selectedLocale)
    }

    private func createUnlockClaimState(
        for unlockAt: BlockNumber,
        block: BlockNumber,
        blockTime: BlockTime
    ) -> GovernanceUnlocksViewModel.ClaimState {
        if block < unlockAt {
            let remainedTimeInSeconds = block.secondsTo(block: unlockAt, blockDuration: blockTime)

            if let leftTime = remainedTimeInSeconds.localizedDaysOrTime(for: selectedLocale) {
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

        let claimState = createUnlockClaimState(for: unlockAt, block: block, blockTime: blockTime)

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
}

extension GovernanceUnlockSetupPresenter: GovernanceUnlockSetupPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func unlock() {}
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
    }

    func didReceiveBlockTime(_ time: BlockTime) {
        blockTime = time

        updateView()
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

extension GovernanceUnlockSetupPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
