import Foundation
import Operation_iOS
import Keystore_iOS
import Foundation_iOS
import BigInt

final class StakingRewardsHandler: CommonHandler, PushNotificationHandler {
    let operationQueue: OperationQueue
    let callStore = CancellableCallStore()
    let chainId: ChainModel.Id
    let payload: StakingRewardPayload

    init(
        chainId: ChainModel.Id,
        payload: StakingRewardPayload,
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

        let contentWrapper: CompoundOperationWrapper<NotificationContentResult> =
            OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                guard let self else {
                    throw PushNotificationsHandlerErrors.undefined
                }

                let chains = try chainOperation.extractNoCancellableResultData()

                guard let chain = self.search(chainId: chainId, in: chains) else {
                    throw PushNotificationsHandlerErrors.chainNotFound(chainId: chainId)
                }

                guard let asset = chain.utilityAsset() else {
                    throw PushNotificationsHandlerErrors.assetNotFound(assetId: chainId)
                }

                let priceOperation: BaseOperation<[PriceData]>
                if
                    let priceId = asset.priceId,
                    let currency = currencyManager(operationQueue: self.operationQueue)?.selectedCurrency {
                    priceOperation = priceRepository(for: priceId, currencyId: currency.id).fetchAllOperation(with: .init())
                } else {
                    priceOperation = .createWithResult([])
                }
                priceOperation.addDependency(chainOperation)

                let fetchMetaAccountsOperation = self.walletsRepository.fetchAllOperation(with: .init())
                let mapOperaion = ClosureOperation {
                    let price = try priceOperation.extractNoCancellableResultData().first
                    let metaAccounts = try fetchMetaAccountsOperation.extractNoCancellableResultData()

                    return self.updatingContent(
                        metaAccounts: metaAccounts,
                        chainAsset: .init(chain: chain, asset: asset),
                        priceData: price,
                        payload: self.payload
                    )
                }

                mapOperaion.addDependency(priceOperation)
                mapOperaion.addDependency(fetchMetaAccountsOperation)

                return .init(targetOperation: mapOperaion, dependencies: [priceOperation, fetchMetaAccountsOperation])
            }

        contentWrapper.addDependency(operations: [chainOperation])
        let wrapper = contentWrapper.insertingHead(operations: [chainOperation])

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
        metaAccounts: [MetaAccountModel],
        chainAsset: ChainAsset,
        priceData: PriceData?,
        payload: StakingRewardPayload
    ) -> NotificationContentResult {
        let walletName = targetWallet(
            for: payload.recipient,
            chain: chainAsset.chain,
            metaAccounts: metaAccounts
        )?.name

        let walletString = walletName.flatMap { "[\($0)]" } ?? ""
        let title = [
            R.string.localizable.pushNotificationStakingRewardTitle(preferredLanguages: locale.rLanguages),
            walletString
        ].joined(with: .space)
        let balance = balanceViewModel(
            asset: chainAsset.asset,
            amount: payload.amount,
            priceData: priceData,
            workingQueue: operationQueue
        )

        let optPriceString = balance?.price.map { "(\($0))" }
        let amountWithPrice = [balance?.amount, optPriceString].compactMap { $0 }.joined(with: .space)
        let body = R.string.localizable.pushNotificationStakingRewardSubtitle(
            amountWithPrice,
            chainAsset.chain.name,
            preferredLanguages: locale.rLanguages
        )

        return .init(title: title, body: body)
    }
}
