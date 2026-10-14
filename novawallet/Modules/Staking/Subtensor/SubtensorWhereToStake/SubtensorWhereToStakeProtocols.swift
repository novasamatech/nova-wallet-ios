import UIKit

protocol SubtensorWhereToStakeViewProtocol: ControllerBackedProtocol {
    func didReceive(cards: [SubtensorWhereToStakeCardModel], title: String, caption: String)
    func didReceive(page: Int, hasPrevious: Bool, hasNext: Bool)
}

protocol SubtensorWhereToStakePresenterProtocol: AnyObject {
    func setup()
    func selectPage(_ page: Int)
    func movePage(by offset: Int)
    func choose(_ order: SubtensorQuickPickOrder)
}

protocol SubtensorWhereInteractorInputProtocol {
    var orders: [SubtensorQuickPickOrder] { get }
}

protocol SubtensorWhereToStakeWireframeProtocol {
    func showSetup(from view: SubtensorWhereToStakeViewProtocol?, order: SubtensorQuickPickOrder)
}
