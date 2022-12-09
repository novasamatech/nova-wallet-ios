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
    func provideDetails(for address: AccountAddress)
    func processPriceId(from urlString: String)
    func save(newToken: EvmTokenAddRequest)
}

protocol TokensManageAddInteractorOutputProtocol: AnyObject {
    func didReceiveDetails(_ tokenDetails: EvmContractMetadata, for address: AccountAddress)
    func didExtractPriceId(_ priceId: String, from urlString: String)
    func didSaveEvmToken()
    func didReceiveError(_ error: TokensManageAddInteractorError)
}

protocol TokensManageAddWireframeProtocol: AnyObject {}
