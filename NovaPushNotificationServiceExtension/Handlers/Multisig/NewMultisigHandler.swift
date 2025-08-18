import Foundation
import Operation_iOS
import Keystore_iOS
import Foundation_iOS
import BigInt

final class NewMultisigHandler: CommonHandler, PushNotificationHandler {
    let chainId: ChainModel.Id
    let payload: NewMultisigPayload
    let operationQueue: OperationQueue
    let callStore = CancellableCallStore()

    init(
        chainId: ChainModel.Id,
        payload: NewMultisigPayload,
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
        let settingsOperation = settingsRepository.fetchAllOperation(with: .init())
        let chainOperation = chainsRepository.fetchAllOperation(with: .init())

        let contentWrapper: CompoundOperationWrapper<NotificationContentResult> =
            OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                guard let self else {
                    throw PushNotificationsHandlerErrors.undefined
                }

                let settings = try settingsOperation.extractNoCancellableResultData().first
                let chains = try chainOperation.extractNoCancellableResultData()

                guard let chain = self.search(chainId: chainId, in: chains) else {
                    throw PushNotificationsHandlerErrors.chainNotFound(chainId: chainId)
                }

                guard let asset = chain.utilityAsset() else {
                    throw PushNotificationsHandlerErrors.assetNotFound(assetId: chainId)
                }

                let fetchMetaAccountsOperation = self.walletsRepository().fetchAllOperation(with: .init())
                let mapOperaion = ClosureOperation {
                    let metaAccounts = try fetchMetaAccountsOperation.extractNoCancellableResultData()

                    return self.updatingContent(
                        wallets: settings?.wallets ?? [],
                        metaAccounts: metaAccounts,
                        chainAsset: .init(chain: chain, asset: asset),
                        priceData: nil,
                        payload: self.payload
                    )
                }

                mapOperaion.addDependency(fetchMetaAccountsOperation)

                return .init(targetOperation: mapOperaion, dependencies: [fetchMetaAccountsOperation])
            }

        contentWrapper.addDependency(operations: [settingsOperation, chainOperation])
        let wrapper = contentWrapper.insertingHead(operations: [settingsOperation, chainOperation])

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

    private func updatingContent(
        wallets: [Web3Alert.LocalWallet],
        metaAccounts: [MetaAccountModel],
        chainAsset _: ChainAsset,
        priceData _: PriceData?,
        payload: NewMultisigPayload
    ) -> NotificationContentResult {
        let walletName = targetWalletName(
            for: payload.multisigAddress,
            chainId: chainId,
            wallets: wallets,
            metaAccounts: metaAccounts
        )
        let title = R.string.localizable.pushNotificationNewMultisigTitle(
            preferredLanguages: locale.rLanguages
        )
        let subtitle = R.string.localizable.pushNotificationCommonMultisigSubtitle(
            walletName ?? "",
            preferredLanguages: locale.rLanguages
        )
        let body = "test body"

//        let balance = balanceViewModel(
//            asset: chainAsset.asset,
//            amount: payload.amount,
//            priceData: priceData,
//            workingQueue: operationQueue
//        )

//        let optPriceString = balance?.price.map { "(\($0))" }
//        let amountWithPrice = [balance?.amount, optPriceString].compactMap { $0 }.joined(with: .space)

        return .init(
            title: title,
            subtitle: subtitle,
            body: body
        )
    }
}
