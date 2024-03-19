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
            guard let self = self else {
                return
            }
            switch result {
            case let .success(chains):
                guard let chain = self.search(
                    chainId: self.chainId,
                    in: chains
                ) else {
                    completion(nil)
                    return
                }

                let title = R.string.localizable.pushNotificationNewReferendumTitle(
                    preferredLanguages: self.locale.rLanguages
                )

                let subtitle = R.string.localizable.pushNotificationNewReferendumSubtitle(
                    chain.name,
                    self.payload.referendumNumber,
                    preferredLanguages: self.locale.rLanguages
                )
                completion(.init(title: title, subtitle: subtitle))
            case .failure:
                completion(nil)
            }
        }
    }
}
