import Foundation
import SoraFoundation

final class DAppBrowserWidgetPresenter {
    weak var view: DAppBrowserWidgetViewProtocol?
    let interactor: DAppBrowserWidgetInteractorInputProtocol

    let browserTabsViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol

    private var browserTabs: [UUID: DAppBrowserTab] = [:]

    init(
        interactor: DAppBrowserWidgetInteractorInputProtocol,
        browserTabsViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.browserTabsViewModelFactory = browserTabsViewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideBrowserTabs() {
        let viewModel = browserTabsViewModelFactory.createViewModel(
            for: browserTabs,
            locale: selectedLocale
        )

        view?.didReceive(viewModel)
    }
}

// MARK: DAppBrowserWidgetPresenterProtocol

extension DAppBrowserWidgetPresenter: DAppBrowserWidgetPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func closeTabs() {
        interactor.closeTabs()
    }
}

// MARK: DAppBrowserWidgetInteractorOutputProtocol

extension DAppBrowserWidgetPresenter: DAppBrowserWidgetInteractorOutputProtocol {
    func didReceive(_ browserTabs: [UUID: DAppBrowserTab]) {
        self.browserTabs = browserTabs

        provideBrowserTabs()
    }
}

// MARK: Localizable

extension DAppBrowserWidgetPresenter: Localizable {
    func applyLocalization() {
        guard
            let view,
            view.isSetup
        else { return }

        provideBrowserTabs()
    }
}
