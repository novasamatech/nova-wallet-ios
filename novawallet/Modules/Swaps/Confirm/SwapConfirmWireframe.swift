import Foundation

final class SwapConfirmWireframe: SwapConfirmWireframeProtocol {
    func complete(on view: ControllerBackedProtocol?, locale: Locale) {
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
