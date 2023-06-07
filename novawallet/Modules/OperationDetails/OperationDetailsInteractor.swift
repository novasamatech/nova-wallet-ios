import UIKit
import CommonWallet
import BigInt
import RobinHood

enum OperationDetailsInteractorError: Error {
    case unsupportTxType
}

final class OperationDetailsInteractor: AccountFetching {
    weak var presenter: OperationDetailsInteractorOutputProtocol?

    let transaction: TransactionHistoryItem
    let chainAsset: ChainAsset

    var chain: ChainModel { chainAsset.chain }

    let walletRepository: AnyDataProviderRepository<MetaAccountModel>
    let transactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let wallet: MetaAccountModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol

    private var accountAddress: AccountAddress? {
        wallet.fetch(for: chain.accountRequest())?.toAddress()
    }

    private var transactionProvider: StreamableProvider<TransactionHistoryItem>?
    private var priceProvider: AnySingleValueProvider<PriceHistory>?
    private var feePriceProvider: AnySingleValueProvider<PriceHistory>?

    private var priceCalculator: TokenPriceCalculatorProtocol?
    private var feePriceCalculator: TokenPriceCalculatorProtocol?

    init(
        transaction: TransactionHistoryItem,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        transactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    ) {
        self.transaction = transaction
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.walletRepository = walletRepository
        self.transactionLocalSubscriptionFactory = transactionLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
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

    private func extractSlashOperationData(
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        let context = try? transaction.call.map {
            try JSONDecoder().decode(HistoryRewardContext.self, from: $0)
        }

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
            ) { result in
                switch result {
                case let .success(addresses):
                    let model = OperationSlashModel(
                        eventId: eventId,
                        amount: amount,
                        priceData: priceData,
                        validator: addresses.first,
                        era: context?.era
                    )

                    completion(.slash(model))
                case .failure:
                    completion(nil)
                }
            }
        } else {
            let model = OperationSlashModel(
                eventId: eventId,
                amount: amount,
                priceData: priceData,
                validator: nil,
                era: context?.era
            )

            completion(.slash(model))
        }
    }

    private func extractRewardOperationData(
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        let context = try? transaction.call.map {
            try JSONDecoder().decode(HistoryRewardContext.self, from: $0)
        }

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
            ) { result in
                switch result {
                case let .success(addresses):
                    let model = OperationRewardModel(
                        eventId: eventId,
                        amount: amount,
                        priceData: priceData,
                        validator: addresses.first,
                        era: context?.era
                    )

                    completion(.reward(model))
                case .failure:
                    completion(nil)
                }
            }
        } else {
            let model = OperationRewardModel(
                eventId: eventId,
                amount: amount,
                priceData: priceData,
                validator: nil,
                era: context?.era
            )

            completion(.reward(model))
        }
    }

    private func getEventId(from context: HistoryRewardContext?) -> String? {
        guard let eventId = context?.eventId else {
            return nil
        }
        return !eventId.isEmpty ? eventId : nil
    }

    private func extractExtrinsicOperationData(
        newFee: BigUInt?,
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard let accountAddress = accountAddress else {
            completion(nil)
            return
        }

        let fee = newFee ?? transaction.feeInPlankIntOrZero
        let feePriceData = feePriceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
            PriceData.amount($0)
        }

        let currentDisplayAddress = DisplayAddress(
            address: accountAddress,
            username: wallet.name
        )

        let model = OperationExtrinsicModel(
            txHash: transaction.txHash,
            call: transaction.callPath.callName,
            module: transaction.callPath.moduleName,
            sender: currentDisplayAddress,
            fee: fee,
            feePriceData: feePriceData
        )

        completion(.extrinsic(model))
    }

    private func extractContractOperationData(
        newFee: BigUInt?,
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        let fee: BigUInt = newFee ?? transaction.feeInPlankIntOrZero
        let feePriceData = feePriceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
            PriceData.amount($0)
        }

        guard
            let accountResponse = wallet.fetch(for: chain.accountRequest()),
            let currentAccountAddress = try? accountResponse.accountId.toAddress(
                using: chain.chainFormat
            ) else {
            completion(nil)
            return
        }

        let currentDisplayAddress = DisplayAddress(
            address: currentAccountAddress,
            username: wallet.name
        )

        let contractAddress = transaction.receiver.flatMap { try? Data(hex: $0).toAddress(using: chain.chainFormat) }
        let contractDisplayAddress = DisplayAddress(address: contractAddress ?? "", username: "")

        let functionSignature = transaction.call.flatMap { String(data: $0, encoding: .utf8) }

        let model = OperationContractCallModel(
            txHash: transaction.txHash,
            fee: fee,
            feePriceData: feePriceData,
            sender: currentDisplayAddress,
            contract: contractDisplayAddress,
            functionSignature: functionSignature
        )

        completion(.contract(model))
    }

    private func extractTransferOperationData(
        newFee: BigUInt?,
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard let accountAddress = accountAddress else {
            completion(nil)
            return
        }
        let peerAddress = (transaction.sender == accountAddress ? transaction.receiver : transaction.sender) ?? transaction.sender
        let accountId = try? peerAddress.toAccountId(using: chain.chainFormat)
        let peerId = accountId?.toHex() ?? peerAddress

        guard let peerId = try? Data(hexString: peerId) else {
            completion(nil)
            return
        }

        let isOutgoing = transaction.type(for: accountAddress) == .outgoing
        let amount = transaction.amountInPlankIntOrZero
        let priceData = priceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
            PriceData.amount($0)
        }

        let fee = newFee ?? transaction.feeInPlankIntOrZero
        let feePriceData = feePriceCalculator?.calculatePrice(for: UInt64(bitPattern: transaction.timestamp)).map {
            PriceData.amount($0)
        }

        let currentDisplayAddress = DisplayAddress(
            address: accountAddress,
            username: wallet.name
        )

        let txId = transaction.txHash

        _ = fetchDisplayAddress(
            for: [peerId],
            chain: chain,
            repository: walletRepository,
            operationQueue: operationQueue
        ) { result in
            switch result {
            case let .success(otherDisplayAddresses):
                if let otherDisplayAddress = otherDisplayAddresses.first {
                    let model = OperationTransferModel(
                        txHash: txId,
                        amount: amount,
                        amountPriceData: priceData,
                        fee: fee,
                        feePriceData: feePriceData,
                        sender: isOutgoing ? currentDisplayAddress : otherDisplayAddress,
                        receiver: isOutgoing ? otherDisplayAddress : currentDisplayAddress,
                        outgoing: isOutgoing
                    )

                    completion(.transfer(model))
                } else {
                    completion(nil)
                }

            case .failure:
                completion(nil)
            }
        }
    }

    private func extractOperationData(
        replacingIfExists newFee: BigUInt?,
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard let accountAddress = accountAddress else {
            completion(nil)
            return
        }
        switch transaction.type(for: accountAddress) {
        case .incoming, .outgoing:
            extractTransferOperationData(newFee: newFee, completion)
        case .reward:
            extractRewardOperationData(completion)
        case .slash:
            extractSlashOperationData(completion)
        case .extrinsic:
            if chainAsset.asset.isEvmNative {
                extractContractOperationData(newFee: newFee, completion)
            } else {
                extractExtrinsicOperationData(newFee: newFee, completion)
            }
        case .none:
            completion(nil)
        }
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
