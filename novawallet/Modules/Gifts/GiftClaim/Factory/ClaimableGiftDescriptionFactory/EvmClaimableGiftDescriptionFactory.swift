import Foundation
import BigInt
import Operation_iOS

protocol EvmClaimableGiftDescriptionFactoryProtocol {
    func createDescription(
        for claimableGift: ClaimableGiftInfo,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel,
        transferType: EvmTransferType
    ) -> BaseOperation<(ClaimableGiftDescription, EvmFeeModel)>
}

final class EvmClaimableGiftDescriptionFactory {
    let transferCommandFactory: EvmTransferCommandFactory
    let transactionService: EvmTransactionServiceProtocol
    let feeProxy: EvmTransactionFeeProxyProtocol

    var completions: [GiftTransactionFeeId: (PartialDescription, Completion)] = [:]

    let mutex = NSLock()

    init(
        transferCommandFactory: EvmTransferCommandFactory,
        transactionService: EvmTransactionServiceProtocol,
        feeProxy: EvmTransactionFeeProxyProtocol
    ) {
        self.transferCommandFactory = transferCommandFactory
        self.transactionService = transactionService
        self.feeProxy = feeProxy

        self.feeProxy.delegate = self
    }
}

// MARK: - Private

private extension EvmClaimableGiftDescriptionFactory {
    func calculateFee(
        partialDescription: PartialDescription,
        transactionId: GiftTransactionFeeId,
        transferType: EvmTransferType
    ) {
        feeProxy.estimateFee(
            using: transactionService,
            reuseIdentifier: transactionId.rawValue
        ) { [weak self] builder in
            guard let self else { return builder }

            let recipientAccountAddress = try partialDescription.claimingAccountId.toAddress(
                using: partialDescription.chainAsset.chain.chainFormat
            )

            let (newBuilder, _) = try transferCommandFactory.addingTransferCommand(
                to: builder,
                amount: partialDescription.giftAmountWithFee,
                recipient: recipientAccountAddress,
                type: transferType
            )

            return newBuilder
        }
    }
}

// MARK: - EvmClaimableGiftDescriptionFactoryProtocol

extension EvmClaimableGiftDescriptionFactory: EvmClaimableGiftDescriptionFactoryProtocol {
    func createDescription(
        for claimableGift: ClaimableGiftInfo,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel,
        transferType: EvmTransferType
    ) -> BaseOperation<(ClaimableGiftDescription, EvmFeeModel)> {
        AsyncClosureOperation { [weak self] completion in
            guard let self else {
                completion(.failure(BaseOperationError.parentOperationCancelled))
                return
            }

            mutex.lock()
            defer { mutex.unlock() }

            let chainAsset = claimableGift.chainAsset

            let onChainAmountWithFee: OnChainTransferAmount<BigUInt> = .all(value: giftAmountWithFee)

            let claimingAccountId = try claimingWallet().fetchChainAccountId(
                for: chainAsset.chain.accountRequest()
            ) ?? chainAsset.chain.emptyAccountId()

            let transactionId = GiftTransactionFeeId(
                recepientAccountId: claimingAccountId,
                amount: onChainAmountWithFee
            )
            let partialDescription = PartialDescription(
                seed: claimableGift.seed,
                accountId: claimableGift.accountId,
                chainAsset: chainAsset,
                giftAmountWithFee: onChainAmountWithFee,
                claimingAccountId: claimingAccountId
            )

            completions[transactionId] = (partialDescription, completion)

            calculateFee(
                partialDescription: partialDescription,
                transactionId: transactionId,
                transferType: transferType
            )
        }
    }
}

// MARK: - ExtrinsicFeeProxyDelegate

extension EvmClaimableGiftDescriptionFactory: EvmTransactionFeeProxyDelegate {
    func didReceiveFee(
        result: Result<EvmFeeModel, any Error>,
        for identifier: TransactionFeeId
    ) {
        mutex.lock()
        defer { mutex.unlock() }

        guard
            let transactionId = GiftTransactionFeeId(rawValue: identifier),
            let (partialData, completion) = completions[transactionId]
        else { return }

        switch result {
        case let .success(fee):
            let giftAmount = partialData.giftAmountWithFee.map { $0 - fee.fee }

            let description = ClaimableGiftDescription(
                seed: partialData.seed,
                accountId: partialData.accountId,
                amount: giftAmount,
                chainAsset: partialData.chainAsset,
                claimingAccountId: partialData.claimingAccountId
            )

            completion(.success((description, fee)))
        case let .failure(error):
            completion(.failure(error))
        }
    }
}

// MARK: - Private types

extension EvmClaimableGiftDescriptionFactory {
    typealias Completion = (Result<(ClaimableGiftDescription, EvmFeeModel), Error>) -> Void

    struct PartialDescription {
        let seed: Data
        let accountId: AccountId
        let chainAsset: ChainAsset
        let giftAmountWithFee: OnChainTransferAmount<BigUInt>
        let claimingAccountId: AccountId
    }
}
