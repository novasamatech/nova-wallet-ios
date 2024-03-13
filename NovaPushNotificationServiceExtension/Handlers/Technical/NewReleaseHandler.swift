import Foundation
import RobinHood
import SoraKeystore
import BigInt
import SoraFoundation

final class NewReleaseHandler: PushNotificationHandler {
    let payload: NewReleasePayload
    let operationQueue: OperationQueue
    let localizationManager: LocalizationManagerProtocol

    init(
        payload: NewReleasePayload,
        localizationManager: LocalizationManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.payload = payload
        self.localizationManager = localizationManager
        self.operationQueue = operationQueue
    }

    func handle(
        callbackQueue: DispatchQueue?,
        completion: @escaping (NotificationContentResult?) -> Void
    ) {
        dispatchInQueueWhenPossible(callbackQueue) {
            let locale = self.localizationManager.selectedLocale
            let title = R.string.localizable.pushNotificationNewReleaseTitle(preferredLanguages: locale.rLanguages)
            let subtitle = R.string.localizable.pushNotificationNewReleaseSubtitle(
                self.payload.version,
                preferredLanguages: locale.rLanguages
            )

            completion(.init(title: title, subtitle: subtitle))
        }
    }
}
