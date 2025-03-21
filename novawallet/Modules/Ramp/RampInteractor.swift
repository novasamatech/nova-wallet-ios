import UIKit

final class RampInteractor {
    weak var presenter: RampInteractorOutputProtocol!

    let eventCenter: EventCenterProtocol

    init(eventCenter: EventCenterProtocol) {
        self.eventCenter = eventCenter
    }
}

extension RampInteractor: RampInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension RampInteractor: EventVisitorProtocol {
    func processPurchaseCompletion(event _: PurchaseCompleted) {
        presenter.didCompleteOperation()
    }
}
