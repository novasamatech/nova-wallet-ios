import UIKit

protocol LocksViewProtocol: ControllerBackedProtocol {
    func update(viewModel: [LocksViewSectionModel])
    func update(header: String)
    func calculateEstimatedHeight(sections: Int, items: Int) -> CGFloat
}

protocol LocksPresenterProtocol: AnyObject {
    func setup()
}

protocol LocksWireframeProtocol: AnyObject {}
