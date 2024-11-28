import Foundation
import SoraFoundation

final class DAppBrowserWidgetPresenter {
    weak var view: DAppBrowserParentWidgetViewProtocol?
    let interactor: DAppBrowserWidgetInteractorInputProtocol
    let wireframe: DAppBrowserWidgetWireframeProtocol

    let browserTabsViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol

    private var state: DAppBrowserWidgetState = .disabled
    private var browserTabs: [UUID: DAppBrowserTab] = [:]

    init(
        interactor: DAppBrowserWidgetInteractorInputProtocol,
        wireframe: DAppBrowserWidgetWireframeProtocol,
        browserTabsViewModelFactory: DAppBrowserWidgetViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.browserTabsViewModelFactory = browserTabsViewModelFactory
        self.localizationManager = localizationManager
    }

    private func provideModel() {
        let viewModel = browserTabsViewModelFactory.createViewModel(
            for: browserTabs,
            state: state,
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

    func actionDone() {
        guard state == .fullBrowser else { return }

        if browserTabs.isEmpty {
            state = .closed
        } else {
            state = .miniature
        }

        provideModel()

        wireframe.showMiniature(form: view)
    }

    func minimizeBrowser() {
        guard state == .fullBrowser else { return }

        state = .miniature
        provideModel()
    }

    func showBrowser() {
        if browserTabs.count == 1, let tab = browserTabs.values.first {
            wireframe.showBrowser(
                from: view,
                with: tab
            )
        } else {
            wireframe.showBrowser(
                from: view,
                with: nil
            )
        }

        state = .fullBrowser

        provideModel()
    }

    func showBrowser(with tab: DAppBrowserTab?) {
        wireframe.showBrowser(
            from: view,
            with: tab
        )

        state = .fullBrowser

        provideModel()
    }

    func closeTabs() {
        interactor.closeTabs()
    }
}

// MARK: DAppBrowserWidgetInteractorOutputProtocol

extension DAppBrowserWidgetPresenter: DAppBrowserWidgetInteractorOutputProtocol {
    func didReceive(_ browserTabs: [UUID: DAppBrowserTab]) {
        self.browserTabs = browserTabs

        switch state {
        case .disabled:
            state = .closed
        case .closed where !browserTabs.isEmpty:
            state = .fullBrowser
        case .miniature where browserTabs.isEmpty:
            state = .closed
        default:
            break
        }

        provideModel()
    }
}

// MARK: Localizable

extension DAppBrowserWidgetPresenter: Localizable {
    func applyLocalization() {
        guard
            let view,
            view.isSetup
        else { return }

        provideModel()
    }
}
