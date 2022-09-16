import Foundation

protocol WalletCreationFlowCompleting {
    func completeWalletCreation(on view: ControllerBackedProtocol?, flow: WalletCreationFlow)
}

extension WalletCreationFlowCompleting {
    private func completeOnboarding(on _: ControllerBackedProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        let rootAnimator = RootControllerAnimationCoordinator()
        rootAnimator.animateTransition(to: pincodeViewController)
    }

    private func completeAddWallet(on view: ControllerBackedProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        MainTransitionHelper.transitToMainTabBarController(
            closing: navigationController,
            animated: true
        )
    }

    private func completeSwitchWallet(on view: ControllerBackedProtocol?) {
        guard let navigationController = view?.controller.navigationController else {
            return
        }

        navigationController.popToRootViewController(animated: true)
    }

    func completeWalletCreation(on view: ControllerBackedProtocol?, flow: WalletCreationFlow) {
        switch flow {
        case .onboarding:
            completeOnboarding(on: view)
        case .addWallet:
            completeAddWallet(on: view)
        case .switchWallet:
            completeSwitchWallet(on: view)
        }
    }
}
