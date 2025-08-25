import Foundation

final class MultisigNotificationsWireframe {
    let completion: (MultisigNotificationsModel) -> Void
    let applicationConfig: ApplicationConfigProtocol

    init(
        applicationConfig: ApplicationConfigProtocol,
        completion: @escaping (MultisigNotificationsModel) -> Void
    ) {
        self.applicationConfig = applicationConfig
        self.completion = completion
    }
}

// MARK: - MultisigNotificationsWireframeProtocol

extension MultisigNotificationsWireframe: MultisigNotificationsWireframeProtocol {
    func complete(settings: MultisigNotificationsModel) {
        completion(settings)
    }

    func showLearnMore(from view: ControllerBackedProtocol?) {
        guard let view else { return }

        showWeb(
            url: applicationConfig.multisigWikiURL,
            from: view,
            style: .automatic
        )
    }
}
