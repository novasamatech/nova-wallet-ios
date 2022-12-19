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

    private var accountAddress: AccountAddress? {
        wallet.fetch(for: chain.accountRequest())?.toAddress()
    }

    private var transactionProvider: StreamableProvider<TransactionHistoryItem>?

    init(
        transaction: TransactionHistoryItem,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>,
        transactionLocalSubscriptionFactory: TransactionLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.transaction = transaction
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.walletRepository = walletRepository
        self.transactionLocalSubscriptionFactory = transactionLocalSubscriptionFactory
        self.operationQueue = operationQueue
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
        // let context = HistoryRewardContext(context: txData.context ?? [:])
        // let eventId = !context.eventId.isEmpty ? context.eventId : txData.transactionId

        let eventId = transaction.identifier
        let precision = Int16(bitPattern: chainAsset.asset.precision)

        let amount = transaction.amountInPlankInt

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
                        validator: addresses.first,
                        era: nil
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
                validator: nil,
                era: nil
            )

            completion(.slash(model))
        }
    }

    private func extractRewardOperationData(
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        // TODO: Era, eventId
        let eventId = transaction.identifier
        // let eventId = !context.eventId.isEmpty ? context.eventId : transaction.identifier
        let precision = Int16(bitPattern: chainAsset.asset.precision)
        let amount = transaction.amountInPlankInt

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
                        validator: addresses.first,
                        era: nil
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
                validator: nil,
                era: nil
            )

            completion(.reward(model))
        }
    }

    private func extractExtrinsicOperationData(
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard let accountAddress = accountAddress else {
            completion(nil)
            return
        }

        let precision = Int16(bitPattern: chainAsset.asset.precision)
        let fee = transaction.amountInPlankInt

        let currentDisplayAddress = DisplayAddress(
            address: accountAddress,
            username: wallet.name
        )

        let model = OperationExtrinsicModel(
            txHash: transaction.identifier,
            call: transaction.callPath.callName,
            module: transaction.callPath.moduleName,
            sender: currentDisplayAddress,
            fee: fee
        )

        completion(.extrinsic(model))
    }

    private func extractTransferOperationData(
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

        let precision = Int16(bitPattern: chainAsset.asset.precision)

        let amount = transaction.amountInPlankInt

        let fee = transaction.feeInPlankInt

        let currentDisplayAddress = DisplayAddress(
            address: accountAddress,
            username: wallet.name
        )

        let txId = transaction.identifier

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
                        fee: fee,
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
        _ completion: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard let accountAddress = accountAddress else {
            completion(nil)
            return
        }
        switch transaction.type(for: accountAddress) {
        case .incoming, .outgoing:
            extractTransferOperationData(completion)
        case .reward:
            extractRewardOperationData(completion)
        case .slash:
            extractSlashOperationData(completion)
        case .extrinsic:
            extractExtrinsicOperationData(completion)
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

    private func provideModel(overridingBy newStatus: OperationDetailsModel.Status?) {
        extractOperationData { [weak self] operationData in
            if let operationData = operationData {
                self?.provideModel(for: operationData, overridingBy: newStatus)
            } else {
                let error = OperationDetailsInteractorError.unsupportTxType
                self?.presenter?.didReceiveDetails(result: .failure(error))
            }
        }
    }
}

extension OperationDetailsInteractor: OperationDetailsInteractorInputProtocol {
    func setup() {
        provideModel(overridingBy: nil)
        transactionProvider = subscribeToTransaction(for: transaction.identifier, chainId: chain.chainId)
    }
}

extension OperationDetailsInteractor: TransactionLocalStorageSubscriber,
    TransactionLocalSubscriptionHandler {
    func handleTransactions(result: Result<[DataProviderChange<TransactionHistoryItem>], Error>) {
        switch result {
        case let .success(changes):
            if let transaction = changes.reduceToLastChange() {
                switch transaction.status {
                case .success:
                    provideModel(overridingBy: .completed)
                case .failed:
                    provideModel(overridingBy: .failed)
                case .pending:
                    provideModel(overridingBy: .pending)
                }
            }
        case let .failure(error):
            presenter?.didReceiveDetails(result: .failure(error))
        }
    }
}
