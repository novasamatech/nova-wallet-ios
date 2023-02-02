import Foundation

final class DelegateInfoDetailsPresenter {
    weak var view: DelegateInfoDetailsViewProtocol?
    let state: DelegateInfoDetailsState

    init(state: DelegateInfoDetailsState) {
        self.state = state
    }
}

extension DelegateInfoDetailsPresenter: DelegateInfoDetailsPresenterProtocol {
    func setup() {
        view?.didReceive(delegateName: state.name)
        view?.didReceive(delegateInfo: state.longDescription)
    }
}
