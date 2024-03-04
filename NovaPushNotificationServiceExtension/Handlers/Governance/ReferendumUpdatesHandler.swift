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

    init(
        chainId: ChainModel.Id,
        payload: ReferendumStateUpdatePayload,
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
                guard let chain = chains.first(where: { $0.chainId == self.chainId }) else {
                    completion(nil)
                    return
                }
                let content = self.content(from: chain, payload: payload)
                completion(content)
            case .failure:
                completion(nil)
            }
        }
    }

    private func content(
        from chain: ChainModel,
        payload: ReferendumStateUpdatePayload
    ) -> NotificationContentResult {
        switch payload.to {
        case .approved:
            let title = localizedString(
                LocalizationKeys.Governance.referendumApprovedTitle,
                locale: locale
            )
            let subtitle = localizedString(
                LocalizationKeys.Governance.referendumApprovedSubitle,
                with: [chain.name, self.payload.referendumNumber],
                locale: locale
            )
            return .init(title: title, subtitle: subtitle)
        case .rejected:
            let title = localizedString(
                LocalizationKeys.Governance.referendumRejectedTitle,
                locale: locale
            )
            let subtitle = localizedString(
                LocalizationKeys.Governance.referendumRejectedSubitle,
                with: [chain.name, self.payload.referendumNumber],
                locale: locale
            )
            return .init(title: title, subtitle: subtitle)
        default:
            let title = localizedString(
                LocalizationKeys.Governance.referendumStatusUpdatedTitle,
                locale: locale
            )
            let subtitle = localizedString(
                LocalizationKeys.Governance.referendumStatusUpdatedSubitle,
                with: [chain.name,
                       self.payload.referendumNumber,
                       self.payload.from.description(for: locale),
                       self.payload.to.description(for: locale)],
                locale: locale
            )
            return .init(title: title, subtitle: subtitle)
        }
    }
}
