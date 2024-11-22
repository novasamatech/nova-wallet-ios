import Foundation

final class DAppBrowserTabsPresenter {
    weak var view: DAppBrowserTabsViewProtocol?
    let wireframe: DAppBrowserTabsWireframeProtocol
    let interactor: DAppBrowserTabsInteractorInputProtocol

    let selectClosure: (UUID) -> Void

    init(
        interactor: DAppBrowserTabsInteractorInputProtocol,
        wireframe: DAppBrowserTabsWireframeProtocol,
        selectClosure: @escaping (UUID) -> Void
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.selectClosure = selectClosure
    }
}

extension DAppBrowserTabsPresenter: DAppBrowserTabsPresenterProtocol {
    func selectTab(with id: UUID) {
        selectClosure(id)
        wireframe.close(view: view)
    }

    func setup() {
        interactor.setup()
    }
}

extension DAppBrowserTabsPresenter: DAppBrowserTabsInteractorOutputProtocol {
    func didReceiveTabs(_ models: [DAppBrowserTabModel]) {
        view?.didReceive(models)
    }
}
