import SoraFoundation

protocol TokensManageAddViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
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
    func handlePartial(priceIdUrl: String)
    func completePriceIdUrlInput()
    func confirmTokenAdd()
}

protocol TokensManageAddInteractorInputProtocol: AnyObject {
    func provideDetails(for address: AccountAddress)
    func processPriceId(from urlString: String)
    func save(newToken: EvmTokenAddRequest)
}

protocol TokensManageAddInteractorOutputProtocol: AnyObject {
    func didReceiveDetails(_ tokenDetails: EvmContractMetadata, for address: AccountAddress)
    func didExtractPriceId(_ priceId: String, from urlString: String)
    func didSaveEvmToken(_ token: AssetModel)
    func didReceiveError(_ error: TokensManageAddInteractorError)
}

protocol TokensManageAddWireframeProtocol: AnyObject {}
