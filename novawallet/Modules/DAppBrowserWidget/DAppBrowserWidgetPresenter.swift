import Foundation

final class DAppBrowserWidgetPresenter {
    weak var view: DAppBrowserWidgetViewProtocol?
    let wireframe: DAppBrowserWidgetWireframeProtocol
    let interactor: DAppBrowserWidgetInteractorInputProtocol

    init(
        interactor: DAppBrowserWidgetInteractorInputProtocol,
        wireframe: DAppBrowserWidgetWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension DAppBrowserWidgetPresenter: DAppBrowserWidgetPresenterProtocol {
    func setup() {}
}

extension DAppBrowserWidgetPresenter: DAppBrowserWidgetInteractorOutputProtocol {}