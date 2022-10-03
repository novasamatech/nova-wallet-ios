import Foundation

final class ReferendumsPresenter {
    weak var view: ReferendumsViewProtocol?

    let interactor: ReferendumsInteractorInputProtocol
    let wireframe: ReferendumsWireframeProtocol

    init(
        interactor: ReferendumsInteractorInputProtocol,
        wireframe: ReferendumsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension ReferendumsPresenter: ReferendumsPresenterProtocol {}

extension ReferendumsPresenter: VoteChildPresenterProtocol {
    func setup() {}

    func becomeOnline() {}

    func putOffline() {}

    func selectChain() {}
}

extension ReferendumsPresenter: ReferendumsInteractorOutputProtocol {}
