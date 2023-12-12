import Foundation

final class DelegatedAccountsUpdateWireframe: DelegatedAccountsUpdateWireframeProtocol {
    let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true, completion: completion)
    }
}
