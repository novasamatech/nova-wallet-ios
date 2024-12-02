import Foundation

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
            browserView.controller.preferredTransition = .zoom { context in
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
            browserView.controller.preferredTransition = .zoom { _ in
                tabsView.getTabViewForTransition(for: tab.uuid)
            }
        } else {
            // Fallback on earlier versions
        }

        let controllers = view?.controller.navigationController?.viewControllers ?? []

        tabsView.controller.loadViewIfNeeded()

        view?.controller.navigationController?.setViewControllers(
            controllers + [tabsView.controller, browserView.controller],
            animated: true
        )
    }
}
