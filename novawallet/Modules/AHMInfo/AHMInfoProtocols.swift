import Foundation

protocol AHMInfoViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: AHMInfoViewModel)
}

protocol AHMInfoPresenterProtocol: AnyObject {
    func setup()
    func actionGotIt()
    func actionLearnMore()
}

protocol AHMInfoInteractorInputProtocol: AnyObject {
    func setup()
}

protocol AHMInfoInteractorOutputProtocol: AnyObject {
    func didReceive(sourceChain: ChainModel)
    func didReceive(destinationChain: ChainModel)
}

protocol AHMInfoWireframeProtocol: WebPresentable, AlertPresentable, ErrorPresentable {
    func complete(from view: AHMInfoViewProtocol?)
}
