import Foundation

final class TokensManageAddPresenter {
    weak var view: TokensManageAddViewProtocol?
    let wireframe: TokensManageAddWireframeProtocol
    let interactor: TokensManageAddInteractorInputProtocol

    init(
        interactor: TokensManageAddInteractorInputProtocol,
        wireframe: TokensManageAddWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension TokensManageAddPresenter: TokensManageAddPresenterProtocol {
    func setup() {

    }

    func handlePartial(address: String) {

    }

    func handlePartial(symbol: String) {

    }

    func handlePartial(decimals: String) {

    }

    func handlePartial(priceId: String) {

    }

    func confirmTokenAdd() {

    }
}

extension TokensManageAddPresenter: TokensManageAddInteractorOutputProtocol {
    func didReceiveDetails(_ tokenDetails: EvmTokenDetails, for address: AccountAddress) {

    }
    
    func didExtractPriceId(_ priceId: String, from urlString: String) {

    }

    func didSaveEvmToken() {

    }

    func didReceiveError(_ error: TokensManageAddInteractorError) {

    }
}
