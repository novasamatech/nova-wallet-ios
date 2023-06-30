import UIKit

final class AssetsSearchInteractor {
    weak var presenter: AssetsSearchInteractorOutputProtocol?

    let stateObservable: AssetListStateObservable

    init(stateObservable: AssetListStateObservable) {
        self.stateObservable = stateObservable
    }
}

extension AssetsSearchInteractor: AssetsSearchInteractorInputProtocol {
    func setup() {
        stateObservable.addObserver(with: self) { [weak self] _, newState in
            self?.presenter?.didReceive(state: newState.value)
        }
    }
}
