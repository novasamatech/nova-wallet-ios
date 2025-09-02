import Foundation_iOS

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
    func confirmTokenAdd()
}

protocol TokensManageAddInteractorInputProtocol: AnyObject {
    func provideDetails(for address: AccountAddress)
    func save(newToken: EvmTokenAddRequest)
}

protocol TokensManageAddInteractorOutputProtocol: AnyObject {
    func didReceiveDetails(_ tokenDetails: EvmContractMetadata, for address: AccountAddress)
    func didSaveEvmToken(_ result: EvmTokenAddResult)
    func didReceiveError(_ error: TokensManageAddInteractorError)
}

protocol TokensManageAddWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, TokenAddErrorPresentable {
    func complete(from view: TokensManageAddViewProtocol?, result: EvmTokenAddResult, locale: Locale)
}
