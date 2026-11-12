import UIKit

extension MainTabBarViewController {
    var currentMoreItem: MainTabBarMoreItem? {
        let slotController = viewControllers?[safe: MainTabBarIndex.more]

        return moreControllers.first { $0.value === slotController }?.key
    }

    func toggleMoreMenu() {
        if moreMenuView != nil {
            hideMoreMenu(animated: true)
        } else {
            showMoreMenu()
        }
    }

    func showMoreMenu() {
        let selectedItem = selectedIndex == MainTabBarIndex.more ? currentMoreItem : nil

        let menuView = MainTabBarMoreMenuView(selectedItem: selectedItem, locale: selectedLocale)
        menuView.delegate = self
        menuView.show(in: view, above: tabBar)
        menuView.requestDismissOnNewModal { [weak self] in
            self?.presentedModals() ?? []
        }

        moreMenuView = menuView
    }

    func presentedModals() -> [UIViewController] {
        let tabControllers = ((viewControllers ?? []) + moreControllers.values).map {
            ($0 as? UINavigationController)?.topViewController ?? $0
        }
        let presentingControllers = [view.window?.rootViewController, self].compactMap { $0 } + tabControllers

        return presentingControllers
            .compactMap(\.presentedViewController)
            .flatMap { sequence(first: $0, next: \.presentedViewController) }
    }

    func hideMoreMenu(animated: Bool) {
        moreMenuView?.hide(animated: animated)
        moreMenuView = nil
    }

    func placeInMoreSlot(_ item: MainTabBarMoreItem) {
        guard
            let controller = moreControllers[item],
            var controllers = viewControllers,
            controllers.indices.contains(MainTabBarIndex.more),
            controllers[MainTabBarIndex.more] !== controller else {
            return
        }

        controllers[MainTabBarIndex.more] = controller

        setViewControllers(controllers, animated: false)
    }
}

extension MainTabBarViewController: TabBarOverlayShowing {
    var isOverlayShown: Bool {
        moreMenuView != nil
    }
}

extension MainTabBarViewController: MainTabBarMoreMenuViewDelegate {
    func moreMenuView(_: MainTabBarMoreMenuView, didSelect item: MainTabBarMoreItem) {
        hideMoreMenu(animated: true)

        guard selectedIndex != MainTabBarIndex.more || currentMoreItem != item else {
            moreItemNavigationController(for: item)?.popToRootViewController(animated: true)
            return
        }

        selectMoreItem(item)
    }

    func moreMenuViewDidRequestDismiss(_: MainTabBarMoreMenuView) {
        hideMoreMenu(animated: true)
    }
}
