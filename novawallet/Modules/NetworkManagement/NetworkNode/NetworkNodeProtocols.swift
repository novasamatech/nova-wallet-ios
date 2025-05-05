import Foundation_iOS

protocol NetworkNodeViewProtocol: ControllerBackedProtocol {
    func didReceiveUrl(viewModel: InputViewModelProtocol)
    func didReceiveName(viewModel: InputViewModelProtocol)
    func didReceiveChain(viewModel: NetworkViewModel)
    func didReceiveButton(viewModel: NetworkNodeViewLayout.LoadingButtonViewModel)
    func didReceiveTitle(text: String)
}

protocol NetworkNodeWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showNetworkDetails(from view: NetworkNodeViewProtocol?)
}
