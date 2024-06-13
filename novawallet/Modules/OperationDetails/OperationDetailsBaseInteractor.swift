import Foundation
import BigInt
import Operation_iOS

enum OperationDetailsInteractorError: Error {
    case unsupportTxType
}

class OperationDetailsBaseInteractor: AccountFetching, AnyCancellableCleaning {
    weak var presenter: OperationDetailsInteractorOutputProtocol?

    let transaction: TransactionHistoryItem
    let chainAsset: ChainAsset

    var chain: ChainModel { chainAsset.chain }

    let transactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationDataProvider: OperationDetailsDataProviderProtocol
    var priceProviders: [AssetModel.PriceId: AnySingleValueProvider<PriceHistory>] = [:]

    private var transactionProvider: StreamableProvider<TransactionHistoryItem>?
    private var priceCalculators: [AssetModel.PriceId: TokenPriceCalculatorProtocol] = [:]
    private var calculatorFactory = PriceHistoryCalculatorFactory()

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
            calculatorFactory: calculatorFactory,
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

    func setupPriceHistorySubscription() {
        fatalError("This function should be overriden")
    }
}

extension OperationDetailsBaseInteractor: OperationDetailsInteractorInputProtocol {
    func setup() {
        provideModel(overridingBy: nil, newFee: nil)

        transactionProvider = subscribeToTransaction(for: transaction.identifier, chainId: chain.chainId)

        setupPriceHistorySubscription()
    }
}

extension OperationDetailsBaseInteractor: TransactionLocalStorageSubscriber,
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

extension OperationDetailsBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePriceHistory(
        result: Result<PriceHistory?, Error>,
        priceId: AssetModel.PriceId
    ) {
        switch result {
        case let .success(history):
            if let history = history {
                calculatorFactory.replace(history: history, priceId: priceId)
                provideModel(overridingBy: nil, newFee: nil)
            }
        case let .failure(error):
            presenter?.didReceiveDetails(result: .failure(error))
        }
    }
}

extension OperationDetailsBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            setupPriceHistorySubscription()
        }
    }
}
