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

protocol DAppBrowserWidgetWireframeProtocol: AnyObject {
    func showBrowser(
        from view: DAppBrowserParentWidgetViewProtocol?,
        with tab: DAppBrowserTab?
    )

    func showMiniature(from view: DAppBrowserParentWidgetViewProtocol?)
}
