import Foundation

final class SwapConfirmWireframe: SwapConfirmWireframeProtocol {
    let completionClosure: SwapCompletionClosure?

    init(completionClosure: SwapCompletionClosure?) {
        self.completionClosure = completionClosure
    }

    func complete(
        on view: ControllerBackedProtocol?,
        payChainAsset: ChainAsset,
        locale: Locale
    ) {
        let title = R.string.localizable
            .commonTransactionSubmitted(preferredLanguages: locale.rLanguages)

        let presenter = view?.controller.navigationController?.presentingViewController

        presenter?.dismiss(animated: true) {
            self.completionClosure?(payChainAsset)
            self.presentSuccessNotification(title, from: presenter, completion: nil)
        }
    }
}
