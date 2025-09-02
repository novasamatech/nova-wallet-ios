import Foundation_iOS

protocol CustomNetworkViewProtocol: ControllerBackedProtocol {
    func didReceiveNetworkType(_ networkType: CustomNetworkType, show: Bool)
    func didReceiveTitle(text: String)
    func didReceiveUrl(viewModel: InputViewModelProtocol)
    func didReceiveName(viewModel: InputViewModelProtocol)
    func didReceiveCurrencySymbol(viewModel: InputViewModelProtocol)
    func didReceiveChainId(viewModel: InputViewModelProtocol?)
    func didReceiveBlockExplorerUrl(viewModel: InputViewModelProtocol)
    func didReceiveCoingeckoUrl(viewModel: InputViewModelProtocol)
    func didReceiveButton(viewModel: NetworkNodeViewLayout.LoadingButtonViewModel)
}

protocol CustomNetworkWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    ModalAlertPresenting,
    TokenAddErrorPresentable {
    func showNetworksList(
        from view: CustomNetworkViewProtocol?,
        locale: Locale
    )
}
