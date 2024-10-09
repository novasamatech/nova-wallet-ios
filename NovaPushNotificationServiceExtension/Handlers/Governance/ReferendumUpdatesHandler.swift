import Foundation
import Operation_iOS
import SoraKeystore
import BigInt
import SoraFoundation

final class ReferendumUpdatesHandler: CommonHandler, PushNotificationHandler {
    let chainId: ChainModel.Id
    let payload: ReferendumStateUpdatePayload
    let operationQueue: OperationQueue

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
        completion: @escaping (PushNotificationHandleResult) -> Void
    ) {
        let chainOperation = chainsRepository.fetchAllOperation(with: .init())

        execute(
            operation: chainOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: callbackQueue
        ) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case let .success(chains):
                guard let chain = search(chainId: chainId, in: chains) else {
                    completion(.original(.chainNotFound(chainId: chainId)))
                    return
                }

                let content = self.content(from: chain)
                completion(.modified(content))
            case let .failure(error):
                completion(.original(.internalError(error: error)))
            }
        }
    }

    private func content(from chain: ChainModel) -> NotificationContentResult {
        switch payload.toStatus {
        case .approved:
            let title = R.string.localizable.pushNotificationReferendumApprovedTitle(
                preferredLanguages: locale.rLanguages!
            )

            let subtitle = R.string.localizable.pushNotificationReferendumApprovedSubtitle(
                chain.name,
                payload.referendumNumber,
                preferredLanguages: locale.rLanguages!
            )

            return .init(title: title, subtitle: subtitle)
        case .rejected:
            let title = R.string.localizable.pushNotificationReferendumRejectedTitle(
                preferredLanguages: locale.rLanguages!
            )

            let subtitle = R.string.localizable.pushNotificationReferendumRejectedSubtitle(
                chain.name,
                payload.referendumNumber,
                preferredLanguages: locale.rLanguages!
            )

            return .init(title: title, subtitle: subtitle)
        default:
            let title = R.string.localizable.pushNotificationReferendumStatusUpdatedTitle(
                preferredLanguages: locale.rLanguages!
            )

            let subtitle: String

            if let oldStatus = payload.fromStatus {
                subtitle = R.string.localizable.pushNotificationReferendumStatusUpdatedSubtitle(
                    chain.name,
                    payload.referendumNumber,
                    oldStatus.description(for: locale),
                    payload.toStatus.description(for: locale),
                    preferredLanguages: locale.rLanguages!
                )
            } else {
                subtitle = R.string.localizable.pushNotificationReferendumSingleStatusUpdatedSubtitle(
                    chain.name,
                    payload.referendumNumber,
                    payload.toStatus.description(for: locale),
                    preferredLanguages: locale.rLanguages!
                )
            }

            return .init(title: title, subtitle: subtitle)
        }
    }
}
