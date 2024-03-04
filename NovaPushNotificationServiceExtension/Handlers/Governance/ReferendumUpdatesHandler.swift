import Foundation
import RobinHood
import SoraKeystore
import BigInt
import SoraFoundation

final class ReferendumUpdatesHandler: CommonHandler, PushNotificationHandler {
    let chainId: ChainModel.Id
    let payload: ReferendumStateUpdatePayload
    let operationQueue: OperationQueue
    let callStore = CancellableCallStore()
    
    init(chainId: ChainModel.Id,
         payload: ReferendumStateUpdatePayload,
         operationQueue: OperationQueue) {
        self.chainId = chainId
        self.payload = payload
        self.operationQueue = operationQueue
    }
    
    func handle(callbackQueue: DispatchQueue?,
                completion: @escaping (NotificationContentResult?) -> Void) {
        let chainOperation = chainsRepository.fetchAllOperation(with: .init())
    
        execute(operation: chainOperation,
                inOperationQueue: operationQueue,
                backingCallIn: callStore,
                runningCallbackIn: callbackQueue) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .success(let chains):
                guard let chain = chains.first(where: { $0.chainId == self.chainId }) else {
                    completion(nil)
                    return
                }
                switch self.payload.to {
                case .approved:
                    let title = localizedString(LocalizationKeys.Governance.referendumApprovedTitle,
                                                locale: self.locale)
                    let subtitle = localizedString(LocalizationKeys.Governance.referendumApprovedSubitle,
                                                   with: [chain.name, self.payload.referendumNumber],
                                                   locale: self.locale)
                    completion(.init(title: title, subtitle: subtitle))
                case .rejected:
                    let title = localizedString(LocalizationKeys.Governance.referendumRejectedTitle,
                                                locale: self.locale)
                    let subtitle = localizedString(LocalizationKeys.Governance.referendumRejectedSubitle,
                                                   with: [chain.name, self.payload.referendumNumber],
                                                   locale: self.locale)
                    completion(.init(title: title, subtitle: subtitle))
                default:
                    let title = localizedString(LocalizationKeys.Governance.referendumStatusUpdatedTitle,
                                                locale: self.locale)
                    let subtitle = localizedString(LocalizationKeys.Governance.referendumStatusUpdatedSubitle,
                                                   with: [chain.name,
                                                          self.payload.referendumNumber,
                                                          self.payload.from.description(for: locale),
                                                          self.payload.to.description(for: locale)],
                                                   locale: self.locale)
                    completion(.init(title: title, subtitle: subtitle))
                }
            case .failure:
                completion(nil)
            }
        }
    }
    
}
