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
}

private extension SubtensorPositionInteractor {
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
            event.accountId == state.selectedAccount?.chainAccount.accountId else {
            return
        }

        let scheduler = ownTradeScheduler ?? Scheduler(with: self, callbackQueue: .main)
        ownTradeScheduler = scheduler
        isOwnTradeSettleDue = false

        scheduler.notifyAfter(SubtensorCostBasisService.ownTradeSettleTime)
        presenter?.didReceiveOwnTradeSettling(true)
    }
}

extension SubtensorPositionInteractor: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        isOwnTradeSettleDue = true
        loadCostBasis()
    }
}
