import Foundation

final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
    func proceed(from view: UsernameSetupViewProtocol?, walletName: String) {
        guard let accountCreation = AccountCreateViewFactory
            .createViewForOnboarding(walletName: walletName)
        else { return }

        view?.controller.navigationController?.pushViewController(
            accountCreation.controller,
            animated: true
        )
    }
}
