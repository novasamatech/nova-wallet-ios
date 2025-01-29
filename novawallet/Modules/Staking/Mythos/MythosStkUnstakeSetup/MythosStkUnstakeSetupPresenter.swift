import Foundation

final class MythosStkUnstakeSetupPresenter {
    weak var view: MythosStkUnstakeSetupViewProtocol?
    let wireframe: MythosStkUnstakeSetupWireframeProtocol
    let interactor: MythosStkUnstakeSetupInteractorInputProtocol

    init(
        interactor: MythosStkUnstakeSetupInteractorInputProtocol,
        wireframe: MythosStkUnstakeSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension MythosStkUnstakeSetupPresenter: MythosStkUnstakeSetupPresenterProtocol {
    func setup() {}
}

extension MythosStkUnstakeSetupPresenter: MythosStkUnstakeSetupInteractorOutputProtocol {
    func didReceiveDelegationIdentities(_: [AccountId: AccountIdentity]?) {}

    func didReceiveBalance(_: AssetBalance?) {}

    func didReceivePrice(_: PriceData?) {}

    func didReceiveStakingDetails(_: MythosStakingDetails?) {}

    func didReceiveClaimableRewards(_: MythosStakingClaimableRewards?) {}

    func didReceiveStakingDuration(_: MythosStakingDuration) {}

    func didReceiveFee(_: ExtrinsicFeeProtocol) {}

    func didReceiveBaseError(_: MythosStkUnstakeInteractorError) {}
}
