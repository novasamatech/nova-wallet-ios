import Foundation
import BigInt
import RobinHood

enum OperationDetailsInteractorError: Error {
    case unsupportTxType
}

final class OperationDetailsInteractor: AccountFetching, AnyCancellableCleaning {
    weak var presenter: OperationDetailsInteractorOutputProtocol?

    let transaction: TransactionHistoryItem
    let chainAsset: ChainAsset

    var chain: ChainModel { chainAsset.chain }

    let transactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationDataProvider: OperationDetailsDataProviderProtocol

    private var transactionProvider: StreamableProvider<TransactionHistoryItem>?
    private var priceProvider: AnySingleValueProvider<PriceHistory>?
    private var feePriceProvider: AnySingleValueProvider<PriceHistory>?

    private var priceCalculator: TokenPriceCalculatorProtocol?
    private var feePriceCalculator: TokenPriceCalculatorProtocol?

    init(
        transaction: TransactionHistoryItem,
        chainAsset: ChainAsset,
        transactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationDataProvider: OperationDetailsDataProviderProtocol
    ) {
        self.transaction = transaction
        self.chainAsset = chainAsset
        self.transactionLocalSubscriptionFactory = transactionLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationDataProvider = operationDataProvider
        self.currencyManager = currencyManager
    }

    private func extractStatus(
        overridingBy newStatus: OperationDetailsModel.Status?
    ) -> OperationDetailsModel.Status {
        if let newStatus = newStatus {
            return newStatus
        } else {
            switch transaction.status {
            case .success:
                return .completed
            case .pending:
                return .pending
            case .failed:
                return .failed
            }
        }
    }

    private func extractOperationData(
        replacingIfExists newFee: BigUInt?,
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        operationDataProvider.extractOperationData(
            replacingWith: newFee,
            priceCalculator: priceCalculator,
            feePriceCalculator: feePriceCalculator,
            progressClosure: completion
        )
    }

    private func provideModel(
        for operationData: OperationDetailsModel.OperationData,
        overridingBy newStatus: OperationDetailsModel.Status?
    ) {
        let time = Date(timeIntervalSince1970: TimeInterval(transaction.timestamp))
        let status = extractStatus(overridingBy: newStatus)

        let details = OperationDetailsModel(
            time: time,
            status: status,
            operation: operationData
        )

        presenter?.didReceiveDetails(result: .success(details))
    }

    private func provideModel(
        overridingBy newStatus: OperationDetailsModel.Status?,
        newFee: BigUInt?
    ) {
        extractOperationData(replacingIfExists: newFee) { [weak self] operationData in
            if let operationData = operationData {
                self?.provideModel(for: operationData, overridingBy: newStatus)
            } else {
                let error = OperationDetailsInteractorError.unsupportTxType
                self?.presenter?.didReceiveDetails(result: .failure(error))
            }
        }
    }

    private func setupPriceHistorySubscription() {
        priceProvider = priceHistoryProvider(for: chainAsset.asset)

        let utilityAsset = chainAsset.chain.utilityAsset()
        feePriceProvider = utilityAsset?.priceId == chainAsset.asset.priceId ?
            priceProvider : priceHistoryProvider(for: utilityAsset)
    }

    private func priceHistoryProvider(for asset: AssetModel?) -> AnySingleValueProvider<PriceHistory>? {
        guard let asset = asset else {
            return nil
        }
        guard let priceId = asset.priceId else {
            return nil
        }

        return subscribeToPriceHistory(for: priceId, currency: selectedCurrency)
    }
}

extension OperationDetailsInteractor: OperationDetailsInteractorInputProtocol {
    func setup() {
        provideModel(overridingBy: nil, newFee: nil)

        transactionProvider = subscribeToTransaction(for: transaction.identifier, chainId: chain.chainId)

        setupPriceHistorySubscription()
    }
}

extension OperationDetailsInteractor: TransactionLocalStorageSubscriber,
    TransactionLocalSubscriptionHandler {
    func handleTransactions(result: Result<[DataProviderChange<TransactionHistoryItem>], Error>) {
        switch result {
        case let .success(changes):
            if let transaction = changes.reduceToLastChange() {
                let newFee = transaction.fee.flatMap { BigUInt($0) }
                switch transaction.status {
                case .success:
                    provideModel(overridingBy: .completed, newFee: newFee)
                case .failed:
                    provideModel(overridingBy: .failed, newFee: newFee)
                case .pending:
                    provideModel(overridingBy: .pending, newFee: newFee)
                }
            }
        case let .failure(error):
            presenter?.didReceiveDetails(result: .failure(error))
        }
    }
}

extension OperationDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePriceHistory(
        result: Result<PriceHistory?, Error>,
        priceId: AssetModel.PriceId
    ) {
        switch result {
        case let .success(history):
            if let history = history {
                if chainAsset.asset.priceId == priceId {
                    priceCalculator = TokenPriceCalculator(history: history)
                }
                if chainAsset.chain.utilityAsset()?.priceId == priceId {
                    feePriceCalculator = TokenPriceCalculator(history: history)
                }
                provideModel(overridingBy: nil, newFee: nil)
            }

        case let .failure(error):
            presenter?.didReceiveDetails(result: .failure(error))
        }
    }
}

extension OperationDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            setupPriceHistorySubscription()
        }
    }
}
