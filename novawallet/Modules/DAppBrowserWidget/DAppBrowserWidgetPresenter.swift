import Foundation

final class DAppBrowserWidgetPresenter {
    weak var view: DAppBrowserWidgetViewProtocol?
    let wireframe: DAppBrowserWidgetWireframeProtocol
    let interactor: DAppBrowserWidgetInteractorInputProtocol

    let browserTabsViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol

    private var browserTabs: [UUID: DAppBrowserTab] = [:]

    init(
        interactor: DAppBrowserWidgetInteractorInputProtocol,
        wireframe: DAppBrowserWidgetWireframeProtocol,
        browserTabsViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.browserTabsViewModelFactory = browserTabsViewModelFactory
    }

    private func provideBrowserTabs() {
        let viewModel = browserTabsViewModelFactory.createViewModel(for: browserTabs)

        view?.didReceive(viewModel)
    }
}

extension DAppBrowserWidgetPresenter: DAppBrowserWidgetPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func closeTabs() {
        interactor.closeTabs()
    }
}

extension DAppBrowserWidgetPresenter: DAppBrowserWidgetInteractorOutputProtocol {
    func didReceive(_ browserTabs: [UUID: DAppBrowserTab]) {
        self.browserTabs = browserTabs

        provideBrowserTabs()
    }
}
