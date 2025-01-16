import Foundation
import Foundation_iOS

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

    private func provideModel(
        with transitionBuilder: DAppBrowserWidgetTransitionBuilder? = nil
    ) {
        let viewModel = browserTabsViewModelFactory.createViewModel(
            for: browserTabs,
            state: state,
            transitionBuilder: transitionBuilder,
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

    func actionDone(transitionBuilder: DAppBrowserWidgetTransitionBuilder) {
        guard state == .fullBrowser else { return }

        if browserTabs.isEmpty {
            state = .closed
        } else {
            state = .miniature
        }

        transitionBuilder.setChildNavigation { [weak self] completion in
            guard let self else { return }

            wireframe.showMiniature(from: view)
            completion()
        }

        provideModel(with: transitionBuilder)
    }

    func minimizeBrowser(transitionBuilder: DAppBrowserWidgetTransitionBuilder) {
        guard state == .fullBrowser || state == .closed else { return }

        state = .miniature

        transitionBuilder.setChildNavigation { [weak self] completion in
            guard let self else { return }

            wireframe.showMiniature(from: view)
            completion()
        }

        provideModel(with: transitionBuilder)
    }

    func showBrowser(transitionBuilder: DAppBrowserWidgetTransitionBuilder) {
        state = .fullBrowser

        transitionBuilder.setChildNavigation { [weak self] completion in
            guard let self else { return }

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

            completion()
        }

        provideModel(with: transitionBuilder)
    }

    func showBrowser(
        with tab: DAppBrowserTab?,
        transitionBuilder: DAppBrowserWidgetTransitionBuilder
    ) {
        state = .fullBrowser

        transitionBuilder.setChildNavigation { [weak self] completion in
            guard let self else { return }

            wireframe.showBrowser(
                from: view,
                with: tab
            )

            completion()
        }

        provideModel(with: transitionBuilder)
    }

    func closeTabs() {
        if browserTabs.count > 1 {
            wireframe.presentCloseTabsAlert(
                from: view,
                with: selectedLocale
            ) { [weak self] in
                self?.interactor.closeTabs()
            }
        } else {
            interactor.closeTabs()
        }
    }
}

// MARK: DAppBrowserWidgetInteractorOutputProtocol

extension DAppBrowserWidgetPresenter: DAppBrowserWidgetInteractorOutputProtocol {
    func didReceive(_ browserTabs: [UUID: DAppBrowserTab]) {
        self.browserTabs = browserTabs

        switch state {
        case .disabled where !browserTabs.isEmpty:
            state = .closed
            view?.didReceiveRequestForMinimizing()
        case .closed where !browserTabs.isEmpty:
            view?.didReceiveRequestForMinimizing()
        case .miniature where browserTabs.isEmpty:
            state = .closed
            provideModel()
        default:
            break
        }
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
