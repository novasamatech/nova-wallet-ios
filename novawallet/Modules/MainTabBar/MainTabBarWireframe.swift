import UIKit

final class MainTabBarWireframe: MainTabBarWireframeProtocol {
    func presentAccountImport(on view: MainTabBarViewProtocol?, source: SecretSource) {
        guard let tabBarController = view?.controller else {
            return
        }

        guard canPresentImport(on: tabBarController) else {
            return
        }

        guard let importController = AccountImportViewFactory
            .createViewForAdding(for: source)?.controller
        else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: importController)

        let presentingController = tabBarController.topModalViewController
        presentingController.present(navigationController, animated: true, completion: nil)
    }

    func presentScreenIfNeeded(
        on view: MainTabBarViewProtocol?,
        screen: UrlHandlingScreen,
        locale: Locale
    ) {
        guard
            let controller = view?.controller as? UITabBarController,
            canPresentScreenWithoutBreakingFlow(on: controller) else {
            return
        }

        switch screen {
        case let .error(error):
            if let errorContent = error.content(for: locale) {
                let closeAction = R.string.localizable.commonOk(preferredLanguages: locale.rLanguages)
                present(
                    message: errorContent.message,
                    title: errorContent.title,
                    closeAction: closeAction,
                    from: view
                )
            }
        case .staking:
            controller.selectedIndex = MainTabBarIndex.staking
        case let .gov(rederendumIndex):
            openGovernanceScreen(in: controller, rederendumIndex: rederendumIndex)
        case let .dApp(dApp):
            controller.selectedIndex = MainTabBarIndex.dapps
            let dappViewController = controller.viewControllers?[MainTabBarIndex.dapps]
            (dappViewController as? UINavigationController)?.popToRootViewController(animated: true)
            if let dappView: DAppListViewProtocol = dappViewController?.contentViewController() {
                dappView.didReceive(dApp: dApp)
            }
        }
    }

    func presentScreenIfNeeded(
        on view: MainTabBarViewProtocol?,
        screen: PushNotification.OpenScreen
    ) {
        guard
            let controller = view?.controller as? UITabBarController,
            canPresentScreenWithoutBreakingFlow(on: controller) else {
            return
        }

        switch screen {
        case let .gov(rederendumIndex):
            openGovernanceScreen(in: controller, rederendumIndex: rederendumIndex)
        case let .historyDetails(chainAsset):
            openAssetDetailsScreen(in: controller, chainAsset: chainAsset)
        case .error:
            break
        }
    }

    private func openGovernanceScreen(
        in controller: UITabBarController,
        rederendumIndex: Referenda.ReferendumIndex
    ) {
        controller.selectedIndex = MainTabBarIndex.vote
        let govViewController = controller.viewControllers?[MainTabBarIndex.vote]
        (govViewController as? UINavigationController)?.popToRootViewController(animated: true)
        if let govController: VoteViewProtocol = govViewController?.contentViewController() {
            govController.showReferendumsDetails(rederendumIndex)
        }
    }

    private func openAssetDetailsScreen(
        in controller: UITabBarController,
        chainAsset: ChainAsset
    ) {
        controller.selectedIndex = MainTabBarIndex.wallet
        let viewController = controller.viewControllers?[MainTabBarIndex.wallet]
        let navigationController = viewController as? UINavigationController
        navigationController?.popToRootViewController(animated: true)

        let operationState = AssetOperationState(
            assetListObservable: .init(state: .init(value: .init())),
            swapCompletionClosure: nil
        )
        guard let detailsView = AssetDetailsContainerViewFactory.createView(
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            operationState: operationState
        ) else {
            return
        }

        navigationController?.pushViewController(
            detailsView.controller,
            animated: true
        )
    }

    // MARK: Private

    private func canPresentScreenWithoutBreakingFlow(on view: UIViewController) -> Bool {
        guard let tabBarController = view.topModalViewController as? UITabBarController else {
            // some flow is currently presented modally
            return false
        }

        if
            let navigationController = tabBarController.selectedViewController as? ImportantFlowNavigationController,
            navigationController.viewControllers.count > 1 {
            // some flow is in progress in the navigation
            return false
        }

        return true
    }

    private func canPresentImport(on view: UIViewController) -> Bool {
        if isAuthorizing || isAlreadyImporting(on: view) {
            return false
        }

        return true
    }

    private func isAlreadyImporting(on view: UIViewController) -> Bool {
        let topViewController = view.topModalViewController
        let topNavigationController: UINavigationController?

        if let navigationController = topViewController as? UINavigationController {
            topNavigationController = navigationController
        } else if let tabBarController = topViewController as? UITabBarController {
            topNavigationController = tabBarController.selectedViewController as? UINavigationController
        } else {
            topNavigationController = nil
        }

        return topNavigationController?.viewControllers.contains {
            if
                ($0 as? OnboardingMainViewProtocol) != nil ||
                ($0 as? AccountImportViewProtocol) != nil ||
                ($0 as? AdvancedWalletViewProtocol) != nil {
                return true
            } else {
                return false
            }
        } ?? false
    }
}
