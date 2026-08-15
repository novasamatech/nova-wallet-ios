import Foundation

final class LegalConsentWireframe: LegalConsentWireframeProtocol {
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func complete(from view: LegalConsentViewProtocol?) {
        view?.controller.dismiss(animated: true) { [completion] in
            completion()
        }
    }
}
