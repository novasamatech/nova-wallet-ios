import Foundation

class WalletBaseManageWireframe: WalletsListWireframe {
    func showOnboarding(from _: WalletManageViewProtocol?) {
        guard let onboarding = OnboardingMainViewFactory.createViewForAdding() else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: onboarding.controller)

        let rootAnimator = RootControllerAnimationCoordinator()
        rootAnimator.animateTransition(to: navigationController)
    }
}

final class WalletManageWireframe: WalletBaseManageWireframe, WalletManageWireframeProtocol {
    func showWalletDetails(from view: WalletManageViewProtocol?, metaAccount: MetaAccountModel) {
        guard let chainManagementView = AccountManagementViewFactory.createView(for: metaAccount.identifier) else {
            return
        }

        chainManagementView.controller.hidesBottomBarWhenPushed = true

        view?.controller.navigationController?.pushViewController(
            chainManagementView.controller,
            animated: true
        )
    }

    func showCreateWalletWithManualBackup(from view: WalletManageViewProtocol?) {
        PostHogAnalyticsService.shared.track(.onboardingStarted(source: .addWallet))
        PostHogAnalyticsService.shared.track(.walletCreationMethodSelected(method: .create))

        guard let onboarding = UsernameSetupViewFactory.createViewForAdding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(onboarding.controller, animated: true)
        }
    }

    func showCreateWalletWithCloudBackup(from view: WalletManageViewProtocol?) {
        PostHogAnalyticsService.shared.track(.onboardingStarted(source: .addWallet))
        PostHogAnalyticsService.shared.track(.walletCreationMethodSelected(method: .cloudBackup))

        guard let onboarding = CloudBackupAddWalletViewFactory.createViewForAdding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(onboarding.controller, animated: true)
        }
    }

    func showImportWallet(from view: WalletManageViewProtocol?) {
        PostHogAnalyticsService.shared.track(.onboardingStarted(source: .addWallet))
        PostHogAnalyticsService.shared.track(.walletCreationMethodSelected(method: .importMnemonic))

        guard let importView = WalletImportOptionsViewFactory.createViewForAdding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(importView.controller, animated: true)
        }
    }
}
