import Foundation
import UIKit

// MARK: CHILD -> WIDGET

typealias DAppBrowserParentWidgetViewProtocol = DAppBrowserWidgetViewProtocol
    & DAppBrowserParentViewProtocol

// MARK: CONTAINER -> WIDGET

protocol DAppBrowserWidgetProtocol {
    var view: UIView! { get set }

    func openBrowser(with tab: DAppBrowserTab?)
}

// MARK: PRESENTER -> VIEW

protocol DAppBrowserWidgetViewProtocol: ControllerBackedProtocol {
    func didReceive(_ browserWidgetModel: DAppBrowserWidgetModel)
    func didReceiveRequestForMinimizing()
}

// MARK: VIEW -> PRESENTER

protocol DAppBrowserWidgetPresenterProtocol: AnyObject {
    func setup()
    func showBrowser(transitionBuilder: DAppBrowserWidgetTransitionBuilder)
    func showBrowser(
        with tab: DAppBrowserTab?,
        transitionBuilder: DAppBrowserWidgetTransitionBuilder
    )
    func actionDone(transitionBuilder: DAppBrowserWidgetTransitionBuilder)
    func minimizeBrowser(transitionBuilder: DAppBrowserWidgetTransitionBuilder)
    func closeTabs()
}

// MARK: PRESENTER -> INTERACTOR

protocol DAppBrowserWidgetInteractorInputProtocol: AnyObject {
    func setup()
    func closeTabs()
}

// MARK: INTERACTOR -> PRESENTER

protocol DAppBrowserWidgetInteractorOutputProtocol: AnyObject {
    func didReceive(_ browserTabs: [UUID: DAppBrowserTab])
}

// MARK: PRESENTER -> WIREFRAME

protocol DAppBrowserWidgetWireframeProtocol: AlertPresentable, DAppBrowserTabsClosePresentable {
    func showBrowser(
        from view: DAppBrowserParentWidgetViewProtocol?,
        with tab: DAppBrowserTab?
    )

    func showMiniature(from view: DAppBrowserParentWidgetViewProtocol?)
}

protocol DAppBrowserTabsClosePresentable {
    func presentCloseTabsAlert(
        from view: ControllerBackedProtocol?,
        with locale: Locale,
        onClose: @escaping () -> Void
    )
}

extension DAppBrowserTabsClosePresentable where Self: AlertPresentable {
    func presentCloseTabsAlert(
        from view: ControllerBackedProtocol?,
        with locale: Locale,
        onClose: @escaping () -> Void
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages
        ).localizable.dappWidgetCloseAlertTitle()
        let message = R.string(preferredLanguages: locale.rLanguages
        ).localizable.dappWidgetCloseAlertMessage()
        let cancelActionText = R.string(preferredLanguages: locale.rLanguages
        ).localizable.commonCancel()
        let closeActionText = R.string(preferredLanguages: locale.rLanguages
        ).localizable.commonCloseAll()
        let closeAction = AlertPresentableAction(
            title: closeActionText,
            style: .destructive
        ) { onClose() }

        let alertViewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [closeAction],
            closeAction: cancelActionText
        )

        present(
            viewModel: alertViewModel,
            style: .alert,
            from: view
        )
    }
}
