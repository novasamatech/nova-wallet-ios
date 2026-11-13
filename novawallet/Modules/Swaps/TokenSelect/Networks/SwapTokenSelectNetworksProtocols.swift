import Foundation

protocol SwapTokenSelectNetworksViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [SwapTokenSelectNetworkViewModel])
}

protocol SwapTokenSelectNetworksPresenterProtocol: AnyObject {
    func setup()
    func toggleNetwork(at index: Int)
    func confirm()
}

protocol SwapTokenSelectNetworksWireframeProtocol: AnyObject {
    func close(view: SwapTokenSelectNetworksViewProtocol?)
}
