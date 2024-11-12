import Foundation

final class BrowserWidgetPresenter {
    weak var view: BrowserWidgetViewProtocol?
    let wireframe: BrowserWidgetWireframeProtocol
    let interactor: BrowserWidgetInteractorInputProtocol

    let browserTabsViewModelFactory: BrowserWidgetViewModelFactoryProtocol

    private var browserTabs: [UUID: DAppBrowserTabModel] = [:]

    init(
        interactor: BrowserWidgetInteractorInputProtocol,
        wireframe: BrowserWidgetWireframeProtocol,
        browserTabsViewModelFactory: BrowserWidgetViewModelFactoryProtocol
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

extension BrowserWidgetPresenter: BrowserWidgetPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func closeTabs() {
        interactor.closeTabs()
    }
}

extension BrowserWidgetPresenter: BrowserWidgetInteractorOutputProtocol {
    func didReceive(_ browserTabs: [UUID: DAppBrowserTabModel]) {
        self.browserTabs = browserTabs

        provideBrowserTabs()
    }
}
