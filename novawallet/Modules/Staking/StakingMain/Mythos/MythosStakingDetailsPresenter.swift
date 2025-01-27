import Foundation

final class MythosStakingDetailsPresenter {
    weak var view: StakingMainViewProtocol?
    let wireframe: MythosStakingDetailsWireframeProtocol
    let interactor: MythosStakingDetailsInteractorInputProtocol

    init(
        interactor: MythosStakingDetailsInteractorInputProtocol,
        wireframe: MythosStakingDetailsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension MythosStakingDetailsPresenter: StakingMainChildPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func performRedeemAction() {}

    func performRebondAction() {}

    func performClaimRewards() {}

    func performManageAction(_: StakingManageOption) {}

    func performAlertAction(_: StakingAlert) {}

    func selectPeriod(_: StakingRewardFiltersPeriod) {}
}

extension MythosStakingDetailsPresenter: MythosStakingDetailsInteractorOutputProtocol {
    func didReceivePrice(_: PriceData?) {}

    func didReceiveAssetBalance(_: AssetBalance?) {}

    func didReceiveStakingDetails(_: MythosStakingDetails?) {}

    func didReceiveElectedCollators(_: MythosSessionCollators) {}

    func didReceiveRewardCalculator(_: CollatorStakingRewardCalculatorEngineProtocol) {}

    func didReceiveClaimableRewards(_: MythosStakingClaimableRewards?) {}

    func didReceiveFrozenBalance(_: MythosStakingFrozenBalance) {}
}
