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
            let title = localizedString(
                LocalizationKeys.Technical.newReleaseTitle,
                locale: locale
            )
            let subtitle = localizedString(
                LocalizationKeys.Technical.newReleaseSubtitle,
                with: [self.payload.version],
                locale: locale
            )
            completion(.init(title: title, subtitle: subtitle))
        }
    }
}
