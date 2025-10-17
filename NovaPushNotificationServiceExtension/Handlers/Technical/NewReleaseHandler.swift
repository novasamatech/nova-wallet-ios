import Foundation
import Operation_iOS
import Keystore_iOS
import Foundation_iOS
import BigInt

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
        completion: @escaping (PushNotificationHandleResult) -> Void
    ) {
        dispatchInQueueWhenPossible(callbackQueue) {
            let locale = self.localizationManager.selectedLocale
            let title = R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationNewReleaseTitle()
            let body = R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationNewReleaseSubtitle(
                self.payload.version
            )

            let notificationConentResult: NotificationContentResult = .init(
                title: title,
                body: body
            )

            completion(.modified(notificationConentResult))
        }
    }
}
