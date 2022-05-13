import Foundation

final class StakingParachainPresenter {
    weak var view: StakingMainViewProtocol?

    let interactor: StakingParachainInteractorInputProtocol
    let logger: LoggerProtocol

    init(interactor: StakingParachainInteractorInputProtocol, logger: LoggerProtocol) {
        self.interactor = interactor
        self.logger = logger
    }
}

extension StakingParachainPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func performMainAction() {}

    func performRewardInfoAction() {}

    func performChangeValidatorsAction() {}

    func performSetupValidatorsForBondedAction() {}

    func performStakeMoreAction() {}

    func performRedeemAction() {}

    func performRebondAction() {}

    func performAnalyticsAction() {}

    func performManageAction(_: StakingManageOption) {}
}

extension StakingParachainPresenter: StakingParachainInteractorOutputProtocol {
    func didReceivePrice(_ price: PriceData?) {
        logger.info("Did receive price data: \(price)")
    }

    func didReceiveAssetBalance(_ assetBalance: AssetBalance?) {
        logger.info("Did receive asset balance: \(assetBalance)")
    }

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?) {
        logger.info("Did receive delegator: \(delegator)")
    }

    func didReceiveScheduledRequests(_ requests: [ParachainStaking.ScheduledRequest]?) {
        logger.info("Did receive requests: \(requests)")
    }

    func didReceiveSelectedCollators(_: SelectedRoundCollators) {
        logger.info("Did receive collators")
    }

    func didReceiveRewardCalculator(_: ParaStakingRewardCalculatorEngineProtocol) {
        logger.info("Did receive calculator")
    }

    func didReceiveError(_ error: Error) {
        logger.error("Did receive error: \(error)")
    }
}
