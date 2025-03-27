import UIKit

final class RampInteractor {
    weak var presenter: RampInteractorOutputProtocol!

    let eventCenter: EventCenterProtocol
    let action: RampAction

    init(
        eventCenter: EventCenterProtocol,
        action: RampAction
    ) {
        self.eventCenter = eventCenter
        self.action = action
    }
}

extension RampInteractor: RampInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension RampInteractor: EventVisitorProtocol {
    func processPurchaseCompletion(event _: PurchaseCompleted) {
        presenter.didCompleteOperation(action: action)
    }
}
