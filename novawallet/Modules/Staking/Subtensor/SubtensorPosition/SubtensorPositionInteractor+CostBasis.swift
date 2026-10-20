import Foundation

extension SubtensorPositionInteractor {
    func loadCostBasis() {
        guard let accountId = state.selectedAccount?.chainAccount.accountId else {
            return
        }

        loadCostBasis(
            using: costBasisService,
            accountId: accountId,
            netuid: netuid,
            in: costBasisStore
        ) { [weak self] in
            self?.presenter?.didReceive(costBasis: $0)
            self?.completeOwnTradeSettleIfDue()
        }
    }

    func resumeOwnTradeSettle() {
        guard let accountId = state.selectedAccount?.chainAccount.accountId else {
            return
        }

        if let remaining = costBasisService.remainingSettleTime(for: accountId, netuid: netuid) {
            scheduleOwnTradeSettle(after: remaining)
        } else if ownTradeScheduler?.isScheduled == true {
            ownTradeScheduler?.cancel()
            settleOwnTrade()
        }
    }

    func reloadCostBasisAfterPositionsChange() {
        guard let accountId = state.selectedAccount?.chainAccount.accountId else {
            return
        }

        if let remaining = costBasisService.remainingSettleTime(for: accountId, netuid: netuid) {
            scheduleOwnTradeSettle(after: remaining)
        } else if !costBasisStore.hasCall {
            loadCostBasis()
        }
    }
}

private extension SubtensorPositionInteractor {
    enum Constants {
        static let settleMargin: TimeInterval = 0.01
    }

    func scheduleOwnTradeSettle(after delay: TimeInterval) {
        let scheduler = ownTradeScheduler ?? Scheduler(with: self, callbackQueue: .main)
        ownTradeScheduler = scheduler
        isOwnTradeSettleDue = false

        scheduler.notifyAfter(delay + Constants.settleMargin)
        presenter?.didReceiveOwnTradeSettling(true)
    }

    func settleOwnTrade() {
        guard let accountId = state.selectedAccount?.chainAccount.accountId else {
            presenter?.didReceiveOwnTradeSettling(false)
            return
        }

        isOwnTradeSettleDue = true
        costBasisService.dropSettledOperations(for: accountId, netuid: netuid)
        loadCostBasis()
    }

    func completeOwnTradeSettleIfDue() {
        guard isOwnTradeSettleDue else {
            return
        }

        isOwnTradeSettleDue = false
        presenter?.didReceiveOwnTradeSettling(false)
    }
}

extension SubtensorPositionInteractor: EventVisitorProtocol {
    func processSubtensorStakeChanged(event: SubtensorStakeChanged) {
        guard
            event.chainAssetId == chainAsset.chainAssetId,
            event.netuids?.contains(netuid) ?? true,
            event.accountId == state.selectedAccount?.chainAccount.accountId else {
            return
        }

        scheduleOwnTradeSettle(after: costBasisService.settleTimeAfterOwnTrade(for: event.accountId, netuid: netuid))
    }
}

extension SubtensorPositionInteractor: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        settleOwnTrade()
    }
}
