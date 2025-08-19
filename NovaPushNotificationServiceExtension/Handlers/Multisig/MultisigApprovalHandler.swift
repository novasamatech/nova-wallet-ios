import Foundation
import Operation_iOS

final class MultisigApprovalHandler: CommonMultisigHandler, PushNotificationHandler {
    let payload: MultisigPayloadProtocol

    let callStore = CancellableCallStore()

    init(
        chainId: ChainModel.Id,
        payload: MultisigPayloadProtocol,
        operationQueue: OperationQueue
    ) {
        self.payload = payload

        super.init(
            chainId: chainId,
            operationQueue: operationQueue
        )
    }

    func handle(
        callbackQueue: DispatchQueue?,
        completion: @escaping (PushNotificationHandleResult) -> Void
    ) {
        let chainsOperation = chainsRepository.fetchAllOperation(with: .init())
        let settingsOperation = settingsRepository.fetchAllOperation(with: .init())

        let contentWrapper: CompoundOperationWrapper<NotificationContentResult> =
            OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                guard let self else {
                    throw PushNotificationsHandlerErrors.undefined
                }

                let chains = try chainsOperation.extractNoCancellableResultData()
                let settings = try settingsOperation.extractNoCancellableResultData().first

                let fetchMetaAccountsOperation = self.walletsRepository().fetchAllOperation(with: .init())

                guard let chain = search(chainId: chainId, in: chains) else {
                    throw PushNotificationsHandlerErrors.chainNotFound(chainId: chainId)
                }

                let notificationContentWrapper = self.notificationContentWrapper(
                    wallets: settings?.wallets ?? [],
                    localChainId: chain.chainId,
                    metaAccounts: { try fetchMetaAccountsOperation.extractNoCancellableResultData() },
                    payload: self.payload
                )

                notificationContentWrapper.addDependency(operations: [fetchMetaAccountsOperation])

                return notificationContentWrapper.insertingHead(operations: [fetchMetaAccountsOperation])
            }

        contentWrapper.addDependency(operations: [chainsOperation])
        contentWrapper.addDependency(operations: [settingsOperation])

        let wrapper = contentWrapper
            .insertingHead(operations: [chainsOperation])
            .insertingHead(operations: [settingsOperation])

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: callbackQueue
        ) { result in
            switch result {
            case let .success(content):
                completion(.modified(content))
            case let .failure(error as PushNotificationsHandlerErrors):
                completion(.original(error))
            case let .failure(error):
                completion(.original(.internalError(error: error)))
            }
        }
    }

    private func notificationContentWrapper(
        wallets: [Web3Alert.LocalWallet],
        localChainId: ChainModel.Id,
        metaAccounts: @escaping () throws -> [MetaAccountModel],
        payload: MultisigPayloadProtocol
    ) -> CompoundOperationWrapper<NotificationContentResult> {
        let title = R.string.localizable.pushNotificationMultisigNewTitle(
            preferredLanguages: locale.rLanguages
        )

        let walletNameOperation = ClosureOperation {
            self.targetWalletName(
                for: payload.multisigAddress,
                chainId: self.chainId,
                wallets: wallets,
                metaAccounts: try metaAccounts()
            )
        }

        guard let callData = payload.callData else {
            let mapOperation = ClosureOperation<NotificationContentResult> { [weak self] in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

                return .init(
                    title: title,
                    subtitle: createSubtitle(with: try walletNameOperation.extractNoCancellableResultData()),
                    body: ""
                )
            }

            mapOperation.addDependency(walletNameOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [walletNameOperation]
            )
        }

        let formattedCallWrapper = callFormattingFactory.createFormattingWrapper(
            for: callData,
            chainId: localChainId
        )

        let mapOperation = ClosureOperation<NotificationContentResult> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let formattedCall = try formattedCallWrapper.targetOperation.extractNoCancellableResultData()

            let newMultisigBodyPart = R.string.localizable.pushNotificationMultisigNewBody(
                payload.signatoryAddress.mediumTruncated,
                preferredLanguages: locale.rLanguages
            )

            return .init(
                title: title,
                subtitle: createSubtitle(with: try walletNameOperation.extractNoCancellableResultData()),
                body: createBody(for: formattedCall, adding: newMultisigBodyPart)
            )
        }

        mapOperation.addDependency(walletNameOperation)
        mapOperation.addDependency(formattedCallWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [walletNameOperation] + formattedCallWrapper.allOperations
        )
    }
}
