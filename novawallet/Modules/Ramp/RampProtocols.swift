import UIKit

protocol RampViewProtocol: ControllerBackedProtocol {}

protocol RampPresenterProtocol: AnyObject {
    func setup()
}

protocol RampInteractorInputProtocol: AnyObject {
    func setup()
}

protocol RampInteractorOutputProtocol: AnyObject {
    func didCompleteOperation()
}

protocol RampWireframeProtocol: AnyObject {
    func complete(from view: RampViewProtocol?)
}

protocol RampViewFactoryProtocol: AnyObject {
    static func createView(
        for action: RampAction,
        delegate: RampDelegate
    ) -> RampViewProtocol?
}
