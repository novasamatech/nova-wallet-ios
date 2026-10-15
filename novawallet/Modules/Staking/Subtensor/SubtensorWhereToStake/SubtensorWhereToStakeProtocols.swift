import UIKit

protocol SubtensorWhereToStakeViewProtocol: ControllerBackedProtocol {
    func didReceive(cards: [SubtensorWhereToStakeCardModel], title: String, caption: String)
}

protocol SubtensorWhereToStakePresenterProtocol: AnyObject {
    func setup()
    func choose(_ order: SubtensorQuickPickOrder)
}

protocol SubtensorWhereInteractorInputProtocol {
    var orders: [SubtensorQuickPickOrder] { get }
}

protocol SubtensorWhereToStakeWireframeProtocol {
    func showSetup(from view: SubtensorWhereToStakeViewProtocol?, order: SubtensorQuickPickOrder)
}
