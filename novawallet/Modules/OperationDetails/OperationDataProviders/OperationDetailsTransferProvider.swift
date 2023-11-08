import Foundation
import BigInt
import RobinHood

final class OperationDetailsTransferProvider: OperationDetailsBaseProvider, AccountFetching {
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
}

extension OperationDetailsTransferProvider: OperationDetailsDataProviderProtocol {
    func extractOperationData(
        replacingWith newFee: BigUInt?,
        calculatorFactory: CalculatorFactoryProtocol,
        progressClosure: @escaping (OperationDetailsModel.OperationData?) -> Void
    ) {
        guard let accountAddress = accountAddress else {
            progressClosure(nil)
            return
        }
        let priceCalculator = calculatorFactory.createPriceProvider(for: chainAsset.asset.priceId)
        let feePriceCalculator = calculatorFactory.createPriceProvider(for: chainAsset.chain.utilityAsset()?.priceId)
        let peerAddress = (transaction.sender == accountAddress ? transaction.receiver : transaction.sender)
            ?? transaction.sender
        let accountId = try? peerAddress.toAccountId(using: chain.chainFormat)
        let peerId = accountId?.toHex() ?? peerAddress

        guard let peerId = try? Data(hexString: peerId) else {
            progressClosure(nil)
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
            username: selectedAccount.chainAccount.name
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

                    progressClosure(.transfer(model))
                } else {
                    progressClosure(nil)
                }

            case .failure:
                progressClosure(nil)
            }
        }
    }
}
