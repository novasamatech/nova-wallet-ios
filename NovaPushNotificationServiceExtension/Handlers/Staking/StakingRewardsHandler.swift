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
                guard let chain = chains.first(where: { $0.chainId == self.chainId }),
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

                let mapOperaion = ClosureOperation {
                    let price = try priceOperation.extractNoCancellableResultData().first
                    return self.updatingContent(
                        wallets: settings?.wallets ?? [],
                        chain: chain,
                        asset: asset,
                        price: price,
                        payload: self.payload
                    )
                }

                mapOperaion.addDependency(priceOperation)

                return .init(targetOperation: mapOperaion, dependencies: [priceOperation])
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
        wallets: [Web3AlertWallet],
        chain: ChainModel,
        asset: AssetModel,
        price: PriceData?,
        payload: StakingRewardPayload
    ) -> NotificationContentResult {
        let walletString: String
        if wallets.count > 1 {
            // TODO: after adding metaId in settings
            walletString = "[]"
        } else {
            walletString = ""
        }
        let title = [
            localizedString("", locale: locale),
            walletString
        ].joined(separator: " ")
        let balance = balanceViewModel(
            asset: asset,
            amount: payload.amount,
            priceData: price,

            workingQueue: operationQueue
        )
        let priceString = price.map { "(\($0))" } ?? ""
        let subtitle = localizedString(
            "",
            with: [balance?.amount ?? "", priceString, chain.name],
            locale: locale
        )

        return .init(title: title, subtitle: subtitle)
    }
}
