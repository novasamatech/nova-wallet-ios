import Foundation
import RobinHood
import BigInt

final class OperationDetailsDirectStakingProvider: OperationDetailsBaseProvider, AccountFetching {
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let operationQueue: OperationQueue

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        transaction: TransactionHistoryItem,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.walletRepository = walletRepository
        self.operationQueue = operationQueue

        super.init(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            transaction: transaction
        )
    }

    private func complete(
        for model: OperationRewardOrSlashModel,
        completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard let accountAddress = accountAddress else {
            completion(.reward(model))
            return
        }

        let isReward = transaction.type(for: accountAddress) == .reward

        if isReward {
            completion(.reward(model))
        } else {
            completion(.slash(model))
        }
    }

    private func getEventId(from context: HistoryRewardContext?) -> String? {
        guard let eventId = context?.eventId else {
            return nil
        }
        return !eventId.isEmpty ? eventId : nil
    }
}

extension OperationDetailsDirectStakingProvider: OperationDetailsDataProviderProtocol {
    func extractOperationData(
        replacingWith _: BigUInt?,
        calculatorFactory: CalculatorFactoryProtocol,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        let context = try? transaction.call.map {
            try JSONDecoder().decode(HistoryRewardContext.self, from: $0)
        }

        let priceCalculator = calculatorFactory.createPriceCalculator(for: chainAsset.asset.priceId)
        let eventId = getEventId(from: context) ?? transaction.txHash

        let amount = transaction.amountInPlankIntOrZero
        let priceData = priceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
            PriceData.amount($0)
        }

        if let validatorId = try? transaction.sender.toAccountId() {
            _ = fetchDisplayAddress(
                for: [validatorId],
                chain: chain,
                repository: walletRepository,
                operationQueue: operationQueue
            ) { [weak self] result in
                switch result {
                case let .success(addresses):
                    let model = OperationRewardOrSlashModel(
                        eventId: eventId,
                        amount: amount,
                        priceData: priceData,
                        validator: addresses.first,
                        era: context?.era
                    )

                    self?.complete(for: model, completion: progressClosure)
                case .failure:
                    progressClosure(nil)
                }
            }
        } else {
            let model = OperationRewardOrSlashModel(
                eventId: eventId,
                amount: amount,
                priceData: priceData,
                validator: nil,
                era: context?.era
            )

            complete(for: model, completion: progressClosure)
        }
    }
}
