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
    func didChangeWallet()
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
    func didReceiveWalletChanged()
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
        let title = R.string.localizable.dappWidgetCloseAlertTitle(
            preferredLanguages: locale.rLanguages
        )
        let message = R.string.localizable.dappWidgetCloseAlertMessage(
            preferredLanguages: locale.rLanguages
        )
        let cancelActionText = R.string.localizable.commonCancel(
            preferredLanguages: locale.rLanguages
        )
        let closeActionText = R.string.localizable.commonCloseAll(
            preferredLanguages: locale.rLanguages
        )
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
