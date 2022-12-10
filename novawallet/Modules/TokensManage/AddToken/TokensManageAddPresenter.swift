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
    func setup() {}

    func handlePartial(address _: String) {}

    func handlePartial(symbol _: String) {}

    func handlePartial(decimals _: String) {}

    func handlePartial(priceId _: String) {}

    func confirmTokenAdd() {}
}

extension TokensManageAddPresenter: TokensManageAddInteractorOutputProtocol {
    func didReceiveDetails(_: EvmContractMetadata, for _: AccountAddress) {}

    func didExtractPriceId(_: String, from _: String) {}

    func didSaveEvmToken(_: AssetModel) {}

    func didReceiveError(_: TokensManageAddInteractorError) {}
}
