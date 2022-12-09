import SoraFoundation

protocol TokensManageAddViewProtocol: AnyObject {
    func didReceiveAddress(viewModel: InputViewModelProtocol)
    func didReceiveSymbol(viewModel: InputViewModelProtocol)
    func didReceiveDecimals(viewModel: InputViewModelProtocol)
    func didReceivePriceId(viewModel: InputViewModelProtocol)
}

protocol TokensManageAddPresenterProtocol: AnyObject {
    func setup()
    func handlePartial(address: String)
    func handlePartial(symbol: String)
    func handlePartial(decimals: String)
    func handlePartial(priceId: String)
    func confirmTokenAdd()
}

protocol TokensManageAddInteractorInputProtocol: AnyObject {

}

protocol TokensManageAddInteractorOutputProtocol: AnyObject {}

protocol TokensManageAddWireframeProtocol: AnyObject {}
