import Foundation
import IrohaCrypto

final class AccountImportWireframe: AccountImportWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceed(from _: AccountImportViewProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }

    func showAdvancedSettings(
        from view: AccountImportViewProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings,
        delegate: AdvancedWalletSettingsDelegate
    ) {
        guard let advancedView = AdvancedWalletViewFactory.createView(
            for: secretSource,
            advancedSettings: settings,
            delegate: delegate
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: advancedView.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
