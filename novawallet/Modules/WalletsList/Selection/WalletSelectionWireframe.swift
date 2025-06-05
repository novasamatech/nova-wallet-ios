import UIKit
import UIKit_iOS

final class WalletSelectionWireframe: WalletsListWireframe, WalletSelectionWireframeProtocol {
    func close(view: WalletsListViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func showSettings(from view: WalletsListViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true) {
            self.openWalletManage()
        }
    }

    private func openWalletManage() {
        guard let manageView = WalletManageViewFactory.createViewForSwitching() else {
            return
        }

        guard let tabBarController = UIApplication.shared.tabBarController else {
            return
        }

        let navigationController = tabBarController.selectedViewController as? UINavigationController
        navigationController?.popToRootViewController(animated: false)

        manageView.controller.hidesBottomBarWhenPushed = true

        navigationController?.pushViewController(manageView.controller, animated: true)
    }

    func showDelegatesUpdates(
        from view: ControllerBackedProtocol?,
        initWallets: [ManagedMetaAccountModel]
    ) {
        guard let proxiedsUpdatesView = DelegatedAccountsUpdateViewFactory.createView(
            initWallets: initWallets
        ) else {
            return
        }

        let appearanceAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveEaseOut]
        )
        let dismissalAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveLinear]
        )

        let indicatorSize = CGSize(width: 32.0, height: 3.0)
        let headerStyle = ModalSheetPresentationHeaderStyle(
            preferredHeight: 20.0,
            backgroundColor: R.color.colorBottomSheetBackground()!,
            cornerRadius: 16.0,
            indicatorVerticalOffset: 4.0,
            indicatorSize: indicatorSize,
            indicatorColor: R.color.colorPullIndicator()!
        )
        let style = ModalSheetPresentationStyle(
            sizing: .auto(maxHeight: UIScreen.main.bounds.height * 0.925),
            backdropColor: R.color.colorDimBackground()!,
            headerStyle: headerStyle
        )

        let configuration = ModalSheetPresentationConfiguration(
            contentAppearanceAnimator: appearanceAnimator,
            contentDissmisalAnimator: dismissalAnimator,
            style: style,
            extendUnderSafeArea: true,
            dismissFinishSpeedFactor: 0.6,
            dismissCancelSpeedFactor: 0.6
        )

        let factory = ModalSheetPresentationFactory(configuration: configuration)
        proxiedsUpdatesView.controller.modalTransitioningFactory = factory
        proxiedsUpdatesView.controller.modalPresentationStyle = .custom

        view?.controller.present(proxiedsUpdatesView.controller, animated: true)
    }
}
