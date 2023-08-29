import Foundation
import SoraFoundation
import BigInt

final class NPoolsClaimRewardsPresenter {
    weak var view: NPoolsClaimRewardsViewProtocol?
    let wireframe: NPoolsClaimRewardsWireframeProtocol
    let interactor: NPoolsClaimRewardsInteractorInputProtocol

    init(
        interactor: NPoolsClaimRewardsInteractorInputProtocol,
        wireframe: NPoolsClaimRewardsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NPoolsClaimRewardsPresenter: NPoolsClaimRewardsPresenterProtocol {
    func setup() {}

    func confirm() {}

    func selectAccount() {}

    func select(claimStrategy _: NominationPools.ClaimRewardsStrategy) {}
}

extension NPoolsClaimRewardsPresenter: NPoolsClaimRewardsInteractorOutputProtocol {
    func didReceive(assetBalance _: AssetBalance?) {}

    func didReceive(claimableRewards _: BigUInt?) {}

    func didReceive(price _: PriceData?) {}

    func didReceive(fee _: BigUInt?) {}

    func didReceive(submissionResult _: Result<String, Error>) {}

    func didReceive(error _: NPoolsClaimRewardsError) {}
}
