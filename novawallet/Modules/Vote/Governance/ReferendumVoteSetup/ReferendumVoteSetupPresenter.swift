import Foundation
import BigInt

final class ReferendumVoteSetupPresenter {
    weak var view: ReferendumVoteSetupViewProtocol?
    let wireframe: ReferendumVoteSetupWireframeProtocol
    let interactor: ReferendumVoteSetupInteractorInputProtocol

    init(
        interactor: ReferendumVoteSetupInteractorInputProtocol,
        wireframe: ReferendumVoteSetupWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ReferendumVoteSetupPresenter: ReferendumVoteSetupPresenterProtocol {
    func setup() {}
}

extension ReferendumVoteSetupPresenter: ReferendumVoteSetupInteractorOutputProtocol {
    func didReceiveLockStateDiff(_: GovernanceLockStateDiff) {}

    func didReceiveAccountVotes(
        _: CallbackStorageSubscriptionResult<[ReferendumIdLocal: ReferendumAccountVoteLocal]>
    ) {}

    func didReceiveBlockNumber(_: BlockNumber) {}

    func didReceiveBlockTime(_: BlockTime) {}

    func didReceiveError(_: ReferendumVoteSetupInteractorError) {}

    func didReceiveAssetBalance(_: AssetBalance?) {}

    func didReceivePrice(_: PriceData?) {}

    func didReceiveVotingReferendum(_: ReferendumLocal) {}

    func didReceiveFee(_: BigUInt) {}

    func didReceiveBaseError(_: ReferendumVoteInteractorError) {}
}
