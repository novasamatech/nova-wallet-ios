import Foundation
import RobinHood
import SoraKeystore
import BigInt
import SoraFoundation

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
        completion: @escaping (NotificationContentResult?) -> Void
    ) {
        let settingsOperation = settingsRepository.fetchAllOperation(with: .init())
        let chainOperation = chainsRepository.fetchAllOperation(with: .init())

        let contentWrapper: CompoundOperationWrapper<NotificationContentResult?> =
            OperationCombiningService.compoundWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)) {
                let settings = try settingsOperation.extractNoCancellableResultData().first
                let chains = try chainOperation.extractNoCancellableResultData()
                guard let chain = self.search(chainId: self.chainId, in: chains),
                      let asset = chain.utilityAsset() else {
                    return nil
                }

                let priceOperation: BaseOperation<[PriceData]>
                if let priceId = asset.priceId,
                   let currency = self.currencyManager(operationQueue: self.operationQueue)?.selectedCurrency {
                    priceOperation = self.priceRepository(for: priceId, currencyId: currency.id).fetchAllOperation(with: .init())
                } else {
                    priceOperation = .createWithResult([])
                }
                priceOperation.addDependency(chainOperation)

                let fetchMetaAccountsOperation = self.walletsRepository().fetchAllOperation(with: .init())
                let mapOperaion = ClosureOperation {
                    let price = try priceOperation.extractNoCancellableResultData().first
                    let metaAccounts = try fetchMetaAccountsOperation.extractNoCancellableResultData()
                    return self.updatingContent(
                        wallets: settings?.wallets ?? [],
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
                completion(content)
            case .failure:
                completion(nil)
            }
        }
    }

    private func updatingContent(
        wallets: [Web3Alert.LocalWallet],
        metaAccounts: [MetaAccountModel],
        chainAsset: ChainAsset,
        priceData: PriceData?,
        payload: StakingRewardPayload
    ) -> NotificationContentResult {
        let walletName = targetWalletName(
            for: payload.recipient,
            chainId: chainId,
            wallets: wallets,
            metaAccounts: metaAccounts
        )
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

        let priceString = balance?.price.map { "(\($0))" } ?? ""
        let subtitle = R.string.localizable.pushNotificationStakingRewardSubtitle(
            balance?.amount ?? "",
            priceString,
            chainAsset.chain.name,
            preferredLanguages: locale.rLanguages
        )

        return .init(title: title, subtitle: subtitle)
    }
}
