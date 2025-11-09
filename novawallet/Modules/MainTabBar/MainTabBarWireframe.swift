import UIKit
import UIKit_iOS
import Foundation_iOS

typealias FlowStatusPresentingClosure = (ModalAlertPresenting, ControllerBackedProtocol?) -> Void

final class MainTabBarWireframe {
    private let cardScreenNavigationFactory: CardScreenNavigationFactoryProtocol

    init(cardScreenNavigationFactory: CardScreenNavigationFactoryProtocol) {
        self.cardScreenNavigationFactory = cardScreenNavigationFactory
    }
}

// MARK: - Private

private extension MainTabBarWireframe {
    func getSettingsNavigationController(from view: MainTabBarViewProtocol?) -> UINavigationController? {
        guard let tabBarController = view?.controller as? UITabBarController else {
            return nil
        }

        let settingsViewController = tabBarController.viewControllers?[MainTabBarIndex.settings]

        return settingsViewController as? UINavigationController
    }

    func openGovernanceScreen(
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

    func openCardScreen(
        in view: MainTabBarViewProtocol?,
        cardNavigation: PayCardNavigation?
    ) {
        guard
            let view,
            let tabBarController = view.controller as? UITabBarController
        else { return }

        checkingSupport(
            of: .card,
            for: SelectedWalletSettings.shared.value,
            sheetPresentingView: view
        ) { [weak self] in
            tabBarController.selectedIndex = MainTabBarIndex.wallet
            let viewController = tabBarController.viewControllers?[MainTabBarIndex.wallet]
            let navigationController = viewController as? UINavigationController
            navigationController?.popToRootViewController(animated: true)

            guard let cardView = self?.cardScreenNavigationFactory.createCardScreen(using: cardNavigation) else {
                return
            }

            navigationController?.pushViewController(
                cardView.controller,
                animated: true
            )
        }
    }

    func openAssetDetailsScreen(
        in controller: UITabBarController,
        chainAsset: ChainAsset
    ) {
        controller.selectedIndex = MainTabBarIndex.wallet
        let viewController = controller.viewControllers?[MainTabBarIndex.wallet]
        let navigationController = viewController as? UINavigationController
        navigationController?.popToRootViewController(animated: true)

        // TODO: Check navigation logic here
        let operationState = AssetOperationState(
            assetListObservable: .init(state: .init(value: .init())),
            swapCompletionClosure: nil
        )

        guard let detailsView = AssetDetailsContainerViewFactory.createView(
            chainAsset: chainAsset,
            operationState: operationState
        ) else {
            return
        }

        navigationController?.pushViewController(
            detailsView.controller,
            animated: true
        )
    }

    func openMultisigOperationScreen(
        in controller: UITabBarController,
        operationKey: Multisig.PendingOperation.Key
    ) {
        controller.selectedIndex = MainTabBarIndex.wallet
        let viewController = controller.viewControllers?[MainTabBarIndex.wallet]
        let navigationController = viewController as? UINavigationController
        navigationController?.popToRootViewController(animated: true)

        guard let multisigOperationView = MultisigOperationFetchProxyViewFactory.createView(
            for: operationKey
        ) else {
            return
        }

        let operationNavigationController = NovaNavigationController(
            rootViewController: multisigOperationView.controller
        )

        navigationController?.viewControllers.first?.presentWithCardLayout(
            operationNavigationController,
            animated: true
        )
    }

    func showMultisigEndedAlert(
        in controller: MainTabBarViewProtocol?,
        tabBar: UITabBarController,
        model: MultisigEndedMessageModel,
        locale: Locale
    ) {
        tabBar.selectedIndex = MainTabBarIndex.wallet
        let viewController = tabBar.viewControllers?[MainTabBarIndex.wallet]
        let navigationController = viewController as? UINavigationController
        navigationController?.popToRootViewController(animated: true)

        let localizedModel = model.value(for: locale)

        present(
            message: localizedModel.description,
            title: localizedModel.title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonGotIt(),
            from: controller
        )
    }

    func openTransactionsToSign(in controller: UITabBarController) {
        controller.selectedIndex = MainTabBarIndex.wallet
        let viewController = controller.viewControllers?[MainTabBarIndex.wallet]
        let navigationController = viewController as? UINavigationController
        navigationController?.popToRootViewController(animated: true)

        guard let transactionsToSignView = MultisigOperationsViewFactory.createView() else {
            return
        }

        transactionsToSignView.controller.hidesBottomBarWhenPushed = true

        navigationController?.pushViewController(
            transactionsToSignView.controller,
            animated: true
        )
    }

    func openNotificationsWalletSelect(
        in controller: UITabBarController,
        selectedWallets: [Web3Alert.LocalWallet]?
    ) {
        controller.selectedIndex = MainTabBarIndex.settings
        let viewController = controller.viewControllers?[MainTabBarIndex.settings]
        let navigationController = viewController as? UINavigationController

        guard
            let settingsController = navigationController?.viewControllers.first,
            let notificationManagementView = NotificationsManagementViewFactory.createView(),
            let walletSelectView = NotificationWalletListViewFactory.createView(
                initState: selectedWallets,
                completion: notificationManagementView.getExternalCallbacks().changeWalletSettings
            )
        else {
            return
        }

        let viewControllerStack = [
            settingsController,
            notificationManagementView.controller,
            walletSelectView.controller
        ]

        viewControllerStack.forEach { $0.loadViewIfNeeded() }

        notificationManagementView.controller.hidesBottomBarWhenPushed = true

        navigationController?.setViewControllers(
            viewControllerStack,
            animated: true
        )
    }

    func openAssetHubMigrationInfoScreen(
        in view: MainTabBarViewProtocol?,
        with info: AHMRemoteData
    ) {
        guard let ahmInfoView = AHMInfoViewFactory.createView(info: info) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: ahmInfoView.controller)

        navigationController.barSettings = .init(
            style: .defaultStyle,
            shouldSetCloseButton: false
        )

        navigationController.isModalInPresentation = true

        view?.controller.present(navigationController, animated: true)
    }

    func openClaimGiftScreen(
        in view: MainTabBarViewProtocol?,
        with navigation: GiftClaimNavigation
    ) {
        guard let claimView = GiftClaimViewFactory.createView(
            info: navigation.info,
            totalAmount: navigation.totalAmount
        ) else { return }

        let navigationController = NovaNavigationController(rootViewController: claimView.controller)

        navigationController.barSettings = .init(
            style: .defaultStyle,
            shouldSetCloseButton: true
        )

        navigationController.isModalInPresentation = true

        view?.controller.present(navigationController, animated: true)
    }

    func canPresentScreenWithoutBreakingFlow(on view: UIViewController) -> Bool {
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

    func canPresentImport(on view: UIViewController) -> Bool {
        if isAuthorizing || isAlreadyImporting(on: view) {
            return false
        }

        return true
    }

    func isAlreadyImporting(on view: UIViewController) -> Bool {
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
                ($0 as? AdvancedWalletViewProtocol) != nil ||
                ($0 as? WalletMigrateAcceptViewProtocol) != nil {
                return true
            } else {
                return false
            }
        } ?? false
    }
}

// MARK: - MainTabBarWireframeProtocol

extension MainTabBarWireframe: MainTabBarWireframeProtocol {
    func presentAssetHubMigrationInfoScreen(
        in view: MainTabBarViewProtocol?,
        with info: [AHMRemoteData]
    ) {
        let ahmInfoControllers = info
            .compactMap { AHMInfoViewFactory.createView(info: $0) }
            .map {
                let navigationController = NovaNavigationController(rootViewController: $0.controller)

                navigationController.barSettings = .init(
                    style: .defaultStyle,
                    shouldSetCloseButton: false
                )

                navigationController.isModalInPresentation = true

                return navigationController
            }

        guard let view, !ahmInfoControllers.isEmpty else { return }

        let allControllers = [view.controller] + ahmInfoControllers

        allControllers.enumerated().forEach { index, controller in
            let nextIndex = index + 1

            guard allControllers.count > nextIndex else { return }

            controller.present(allControllers[nextIndex], animated: true)
        }
    }

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

        presentingController.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }

    func presentWalletMigration(on view: MainTabBarViewProtocol?, message: WalletMigrationMessage.Start) {
        guard let tabBarController = view?.controller else {
            return
        }

        guard canPresentImport(on: tabBarController) else {
            return
        }

        guard let acceptView = WalletMigrateAcceptViewFactory.createViewForAdding(from: message) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: acceptView.controller)

        navigationController.barSettings = navigationController.barSettings.bySettingCloseButton(false)
        navigationController.modalPresentationStyle = .fullScreen
        navigationController.modalTransitionStyle = .crossDissolve

        let presentingController = tabBarController.topModalViewController

        presentingController.present(
            navigationController,
            animated: true
        )
    }

    func presentScreenIfNeeded(
        on view: MainTabBarViewProtocol?,
        screen: UrlHandlingScreen,
        locale: Locale
    ) {
        if case let .dApp(model) = screen {
            openBrowser(with: model)
        } else {
            guard
                let controller = view?.controller as? UITabBarController,
                canPresentScreenWithoutBreakingFlow(on: controller) else {
                return
            }

            switch screen {
            case let .error(error):
                if let errorContent = error.content(for: locale) {
                    let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonOk()
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
            case let .card(cardNavigation):
                openCardScreen(in: view, cardNavigation: cardNavigation)
            case let .assetHubMigration(ahmNavigation):
                openAssetHubMigrationInfoScreen(in: view, with: ahmNavigation.config)
            case let .giftClaim(giftNavigation):
                openClaimGiftScreen(in: view, with: giftNavigation)
            default:
                break
            }
        }
    }

    func presentScreenIfNeeded(
        on view: MainTabBarViewProtocol?,
        screen: PushNotification.OpenScreen,
        locale: Locale
    ) {
        guard
            let controller = view?.controller as? UITabBarController,
            canPresentScreenWithoutBreakingFlow(on: controller) else {
            return
        }

        switch screen {
        case let .gov(rederendumIndex):
            openGovernanceScreen(
                in: controller,
                rederendumIndex: rederendumIndex
            )
        case let .historyDetails(chainAsset):
            openAssetDetailsScreen(
                in: controller,
                chainAsset: chainAsset
            )
        case let .multisigOperationDetails(operationKey):
            openMultisigOperationScreen(in: controller, operationKey: operationKey)
        case let .multisigOperationEnded(model):
            showMultisigEndedAlert(in: view, tabBar: controller, model: model, locale: locale)
        case .error:
            break
        }
    }

    func presentPushNotificationsSetup(
        on view: MainTabBarViewProtocol?,
        presentationCompletion: @escaping () -> Void,
        flowCompletion: @escaping (Bool) -> Void
    ) {
        guard let setupPushNotificationsView = NotificationsSetupViewFactory.createView(
            completion: flowCompletion
        ) else {
            return
        }

        setupPushNotificationsView.controller.isModalInPresentation = true

        view?.controller.presentWithCardLayout(
            setupPushNotificationsView.controller,
            animated: true,
            completion: presentationCompletion
        )
    }

    func presentCloudBackupUnsyncedChanges(
        from view: MainTabBarViewProtocol?,
        onReviewUpdates: @escaping () -> Void
    ) {
        guard
            let tabBarController = view?.controller as? UITabBarController,
            canPresentScreenWithoutBreakingFlow(on: tabBarController),
            let bottomSheet = CloudBackupMessageSheetViewFactory.createUnsyncedChangesSheet(
                completionClosure: onReviewUpdates,
                cancelClosure: nil
            ) else {
            return
        }

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    func presentCloudBackupUpdateFailedIfNeeded(
        from view: MainTabBarViewProtocol?,
        onReviewIssues: @escaping () -> Void
    ) {
        guard
            let tabBarController = view?.controller as? UITabBarController,
            canPresentScreenWithoutBreakingFlow(on: tabBarController),
            let bottomSheet = CloudBackupMessageSheetViewFactory.createCloudBackupUpdateFailedSheet(
                completionClosure: onReviewIssues,
                cancelClosure: nil
            ) else {
            return
        }

        view?.controller.present(bottomSheet.controller, animated: true)
    }

    func presentCloudBackupSettings(from view: MainTabBarViewProtocol?) {
        guard let tabBarController = view?.controller as? UITabBarController else {
            return
        }

        tabBarController.selectedIndex = MainTabBarIndex.settings

        let settingsNavigationController = getSettingsNavigationController(from: view)

        let optBackupSettings = settingsNavigationController?.topViewController as? CloudBackupSettingsViewProtocol

        if optBackupSettings == nil {
            settingsNavigationController?.popToRootViewController(animated: false)

            guard let cloudBackupSettings = CloudBackupSettingsViewFactory.createView() else {
                return
            }

            cloudBackupSettings.controller.hidesBottomBarWhenPushed = true

            settingsNavigationController?.pushViewController(cloudBackupSettings.controller, animated: true)
        }
    }

    func presentDelayedOperationCreated(from view: MainTabBarViewProtocol?) {
        guard let tabBarController = view?.controller as? UITabBarController else {
            return
        }

        let bottomSheet = DelegatedMessageSheetViewFactory.createMultisigOpCreated { [weak self] in
            self?.openTransactionsToSign(in: tabBarController)
        }

        guard let controllerToPresent = bottomSheet?.controller else {
            return
        }

        view?.controller.present(controllerToPresent, animated: true)
    }

    func presentMultisigNotificationsPromo(
        from view: MainTabBarViewProtocol?,
        with params: MultisigNotificationsPromoParams
    ) {
        guard let tabBarController = view?.controller as? UITabBarController else {
            return
        }

        let bottomSheet = MultisigNotificationsSheetFactory.createMultisigNotificationsPromo { [weak self] in
            self?.openNotificationsWalletSelect(
                in: tabBarController,
                selectedWallets: params.selectedWallets
            )
        }

        guard let controllerToPresent = bottomSheet?.controller else {
            return
        }

        view?.controller.present(controllerToPresent, animated: true) {
            params.completion()
        }
    }
}
