import Foundation

extension StakingNPoolsViewModelFactory {
    func createStakingAlerts(
        for params: StakingNPoolsViewModelParams,
        status: NominationViewStatus,
        chainAsset: ChainAsset
    ) -> [StakingAlert] {
        [
            findRedeemUnbondedAlert(for: params, chainAsset: chainAsset),
            findWaitingNextEraAlert(nominationStatus: status)
        ].compactMap { $0 }
    }

    private func findRedeemUnbondedAlert(
        for params: StakingNPoolsViewModelParams,
        chainAsset: ChainAsset
    ) -> StakingAlert? {
        guard
            let era = params.activeEra?.index,
            let poolMember = params.poolMember,
            let subPools = params.subPools
        else { return nil }

        let redeemableAmount = subPools.redeemableBalance(for: poolMember, in: era)

        guard redeemableAmount > 0 else {
            return nil
        }

        let localizedString = balanceViewModelFactory.amountFromValue(
            redeemableAmount.decimal(precision: chainAsset.asset.precision)
        )

        return .redeemUnbonded(localizedString)
    }

    private func findWaitingNextEraAlert(nominationStatus: NominationViewStatus) -> StakingAlert? {
        if case NominationViewStatus.waiting = nominationStatus {
            return .waitingNextEra
        }
        return nil
    }
}
