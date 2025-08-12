import Foundation

final class MultisigNotificationsWireframe {
    let completion: (MultisigNotificationsModel) -> Void

    init(completion: @escaping (MultisigNotificationsModel) -> Void) {
        self.completion = completion
    }
}

// MARK: - MultisigNotificationsWireframeProtocol

extension MultisigNotificationsWireframe: MultisigNotificationsWireframeProtocol {
    func complete(settings: MultisigNotificationsModel) {
        completion(settings)
    }
}
