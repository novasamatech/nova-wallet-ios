import Foundation
import UIKit

protocol DAppBrowserNewTabRouterProtocol {
    func process(
        searchResult: DAppSearchResult,
        view: ControllerBackedProtocol?
    )
}

class DAppBrowserNewTabRouter {
    private let tabManager: DAppBrowserTabManagerProtocol
    private let operationQueue: OperationQueue
    private let wireframe: DAppBrowserNewTabOpening

    init(
        tabManager: DAppBrowserTabManagerProtocol,
        operationQueue: OperationQueue,
        wireframe: DAppBrowserNewTabOpening
    ) {
        self.tabManager = tabManager
        self.operationQueue = operationQueue
        self.wireframe = wireframe
    }
}

extension DAppBrowserNewTabRouter: DAppBrowserNewTabRouterProtocol {
    func process(
        searchResult: DAppSearchResult,
        view: ControllerBackedProtocol?
    ) {
        guard let tab = DAppBrowserTab(from: searchResult) else {
            return
        }

        let saveWrapper = tabManager.updateTab(tab)

        execute(
            wrapper: saveWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(tab):
                self?.wireframe.show(tab, from: view)
            case let .failure(error):
                print(error)
            }
        }
    }
}

protocol DAppBrowserNewTabOpening: AnyObject {
    func show(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    )
}

class DAppBrowserNewTabWireframe: DAppBrowserNewTabOpening {
    func show(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    ) {
        guard let browserView = DAppBrowserViewFactory.createView(selectedTab: tab) else {
            return
        }

        if #available(iOS 18.0, *) {
            let options = UIViewController.Transition.ZoomOptions()
            options.alignmentRectProvider = { context in
                guard let destinationController = context.zoomedViewController as? DAppBrowserViewController else {
                    return .zero
                }
                let container = destinationController.rootView.webViewContainer

                return container.convert(container.bounds, to: destinationController.rootView)
            }

            browserView.controller.preferredTransition = .zoom(options: options) { context in
                let source = context.sourceViewController as? DAppBrowserTabViewTransitionProtocol

                return source?.getTabViewForTransition(for: tab.uuid)
            }
        } else {
            // Fallback on earlier versions
        }

        view?.controller.navigationController?.pushViewController(
            browserView.controller,
            animated: true
        )
    }
}

class DAppBrowserNewStackWireframe: DAppBrowserNewTabOpening {
    func show(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let tabsView = DAppBrowserTabListViewFactory.createView(),
            let browserView = DAppBrowserViewFactory.createView(selectedTab: tab)
        else {
            return
        }

        tabsView.controller.hidesBottomBarWhenPushed = true
        browserView.controller.hidesBottomBarWhenPushed = true

        if #available(iOS 18.0, *) {
            let options = UIViewController.Transition.ZoomOptions()
            options.alignmentRectProvider = { context in
                guard let destinationController = context.zoomedViewController as? DAppBrowserViewController else {
                    return .zero
                }
                let container = destinationController.rootView.webViewContainer

                return container.convert(container.bounds, to: destinationController.rootView)
            }

            browserView.controller.preferredTransition = .zoom(options: options) { _ in
                tabsView.getTabViewForTransition(for: tab.uuid)
            }
        } else {
            // Fallback on earlier versions
        }

        tabsView.controller.loadViewIfNeeded()

        let controllers = [tabsView.controller, browserView.controller]

        let navigationController = NovaNavigationController()
        navigationController.barSettings = .defaultSettings.bySettingCloseButton(false)

        navigationController.setViewControllers(
            controllers,
            animated: false
        )

        navigationController.modalPresentationStyle = .overFullScreen

        view?.controller.present(
            navigationController,
            animated: true
        )
    }
}
