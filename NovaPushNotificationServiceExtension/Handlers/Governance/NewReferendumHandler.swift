import Foundation
import RobinHood
import SoraKeystore
import BigInt
import SoraFoundation

final class NewReferendumHandler: CommonHandler, PushNotificationHandler {
    let chainId: ChainModel.Id
    let payload: NewReferendumPayload
    let operationQueue: OperationQueue
    let callStore = CancellableCallStore()

    init(
        chainId: ChainModel.Id,
        payload: NewReferendumPayload,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.payload = payload
        self.operationQueue = operationQueue
    }

    func handle(
        callbackQueue: DispatchQueue?,
        completion: @escaping (NotificationContentResult?) -> Void
    ) {
        let chainOperation = chainsRepository.fetchAllOperation(with: .init())

        execute(
            operation: chainOperation,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: callbackQueue
        ) { [weak self] result in
            switch result {
            case let .success(chains):
                guard let chain = chains.first, let self = self else {
                    completion(nil)
                    return
                }
                let title = localizedString(
                    LocalizationKeys.Governance.newReferendumTitle,

                    locale: self.locale
                )
                let subtitle = localizedString(
                    LocalizationKeys.Governance.newReferendumSubtitle,

                    with: [chain.name, self.payload.referendumNumber],
                    locale: self.locale
                )
                completion(.init(title: title, subtitle: subtitle))
            case .failure:
                completion(nil)
            }
        }
    }
}
