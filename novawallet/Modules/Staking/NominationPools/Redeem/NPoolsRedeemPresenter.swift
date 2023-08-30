import Foundation
import SoraFoundation
import BigInt

final class NPoolsRedeemPresenter {
    weak var view: NPoolsRedeemViewProtocol?
    let wireframe: NPoolsRedeemWireframeProtocol
    let interactor: NPoolsRedeemInteractorInputProtocol

    init(
        interactor: NPoolsRedeemInteractorInputProtocol,
        wireframe: NPoolsRedeemWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension NPoolsRedeemPresenter: NPoolsRedeemPresenterProtocol {
    func setup() {}

    func confirm() {}

    func selectAccount() {}
}

extension NPoolsRedeemPresenter: NPoolsRedeemInteractorOutputProtocol {
    func didReceive(assetBalance _: AssetBalance?) {}

    func didReceive(poolMember _: NominationPools.PoolMember?) {}

    func didReceive(subPools _: NominationPools.SubPools?) {}

    func didReceive(activeEra _: ActiveEraInfo?) {}

    func didReceive(price _: PriceData?) {}

    func didReceive(fee _: BigUInt?) {}

    func didReceive(submissionResult _: Result<String, Error>) {}

    func didReceive(error _: NPoolsRedeemError) {}
}
