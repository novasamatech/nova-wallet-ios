import Foundation
import Operation_iOS
import Keystore_iOS
import Foundation_iOS
import BigInt

final class TransferHandler: CommonHandler, PushNotificationHandler {
    let operationQueue: OperationQueue
    let callStore = CancellableCallStore()
    let chainId: ChainModel.Id
    let payload: NotificationTransferPayload
    let type: PushNotification.TransferType

    init(
        chainId: ChainModel.Id,
        payload: NotificationTransferPayload,
        type: PushNotification.TransferType,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.payload = payload
        self.type = type
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
                    return .createWithError(PushNotificationsHandlerErrors.undefined)
                }

                let settings = try settingsOperation.extractNoCancellableResultData().first
                let chains = try chainOperation.extractNoCancellableResultData()

                guard let chain = search(chainId: chainId, in: chains) else {
                    throw PushNotificationsHandlerErrors.chainNotFound(chainId: chainId)
                }

                guard let asset = mapHistoryAssetId(payload.assetId, chain: chain) else {
                    throw PushNotificationsHandlerErrors.assetNotFound(assetId: chainId)
                }

                let priceOperation: BaseOperation<[PriceData]>
                if let priceId = asset.priceId,
                   let currency = currencyManager(operationQueue: operationQueue)?.selectedCurrency {
                    priceOperation = priceRepository(for: priceId, currencyId: currency.id)
                        .fetchAllOperation(with: .init())
                } else {
                    priceOperation = .createWithResult([])
                }
                priceOperation.addDependency(chainOperation)
                let fetchMetaAccountsOperation = walletsRepository().fetchAllOperation(with: .init())

                let mapOperaion = ClosureOperation {
                    let price = try priceOperation.extractNoCancellableResultData().first
                    let metaAccounts = try fetchMetaAccountsOperation.extractNoCancellableResultData()
                    return self.updatingContent(
                        wallets: settings?.wallets ?? [],
                        metaAccounts: metaAccounts,
                        chainAsset: .init(chain: chain, asset: asset),
                        price: price,
                        payload: self.payload
                    )
                }

                mapOperaion.addDependency(priceOperation)
                mapOperaion.addDependency(fetchMetaAccountsOperation)

                return .init(targetOperation: mapOperaion, dependencies: [priceOperation, fetchMetaAccountsOperation])
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

    private func mapHistoryAssetId(_ assetId: String?, chain: ChainModel) -> AssetModel? {
        if assetId == nil {
            return chain.utilityAsset()
        } else {
            return chain.asset(byHistoryAssetId: assetId)
        }
    }

    private func updatingContent(
        wallets: [Web3Alert.LocalWallet],
        metaAccounts: [MetaAccountModel],
        chainAsset: ChainAsset,
        price: PriceData?,
        payload: NotificationTransferPayload
    ) -> NotificationContentResult {
        let walletName = targetWalletName(wallets: wallets, metaAccounts: metaAccounts)
        let title = type.title(locale: locale, walletName: walletName)

        let balance = balanceViewModel(
            asset: chainAsset.asset,
            amount: payload.amount,
            priceData: price,
            workingQueue: operationQueue
        )
        let address = type.address(from: payload)
        let addressOrName = targetWalletName(
            for: address,
            chainId: chainId,
            wallets: wallets,
            metaAccounts: metaAccounts
        ) ?? address?.truncated

        let subtitle = type.subtitle(
            amount: balance?.amount ?? "",
            price: balance?.price ?? "",
            chainName: chainAsset.chain.name,
            address: addressOrName,
            locale: locale
        )

        return .init(title: title, subtitle: subtitle)
    }

    private func targetWalletName(
        wallets: [Web3Alert.LocalWallet],
        metaAccounts: [MetaAccountModel]
    ) -> String? {
        switch type {
        case .income:
            return targetWalletName(
                for: payload.recipient,
                chainId: chainId,
                wallets: wallets,
                metaAccounts: metaAccounts
            )
        case .outcome:
            return targetWalletName(
                for: payload.sender,
                chainId: chainId,
                wallets: wallets,
                metaAccounts: metaAccounts
            )
        }
    }
}
