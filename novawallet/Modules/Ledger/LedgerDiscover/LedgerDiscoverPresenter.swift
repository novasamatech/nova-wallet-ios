import Foundation

final class LedgerDiscoverPresenter {
    weak var view: LedgerDiscoverViewProtocol?
    let wireframe: LedgerDiscoverWireframeProtocol
    let interactor: LedgerDiscoverInteractorInputProtocol

    init(
        interactor: LedgerDiscoverInteractorInputProtocol,
        wireframe: LedgerDiscoverWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension LedgerDiscoverPresenter: LedgerDiscoverPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension LedgerDiscoverPresenter: LedgerDiscoverInteractorOutputProtocol {
    func didDiscover(device _: LedgerDeviceProtocol) {}
}
