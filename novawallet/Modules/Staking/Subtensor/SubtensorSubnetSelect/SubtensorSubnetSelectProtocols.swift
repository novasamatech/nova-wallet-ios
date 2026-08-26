import Foundation

protocol SubtensorSubnetSelectDelegate: AnyObject {
    func didSelectStakeTarget(_ target: SubtensorStakeTarget)
}

protocol SubtensorSubnetSelectViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [SubtensorSubnetSelectViewModel])
}

protocol SubtensorSubnetSelectPresenterProtocol: AnyObject {
    func setup()
    func search(query: String)
    func select(viewModel: SubtensorSubnetSelectViewModel)
}

protocol SubnetSelectInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol SubnetSelectInteractorOutputProtocol: AnyObject {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo)
    func didReceiveDefaultTake(_ take: UInt16)
    func didReceiveError(_ error: Error)
}

protocol SubtensorSubnetSelectWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func complete(from view: SubtensorSubnetSelectViewProtocol?)
}
