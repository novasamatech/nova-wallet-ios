import Foundation
import BigInt
import Operation_iOS

protocol ClaimableGiftDescriptionFactoryProtocol {
    func createDescription(
        for claimableGift: ClaimableGiftInfo,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel,
        assetStorageInfo: @escaping () throws -> AssetStorageInfo
    ) -> BaseOperation<ClaimableGiftDescription>
}

final class ClaimableGiftDescriptionFactory {
    let transferCommandFactory: SubstrateTransferCommandFactory
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol

    var completions: [GiftTransactionFeeId: (PartialDescription, Completion)] = [:]

    let mutex = NSLock()

    init(
        transferCommandFactory: SubstrateTransferCommandFactory,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol
    ) {
        self.transferCommandFactory = transferCommandFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy

        self.feeProxy.delegate = self
    }
}

// MARK: - Private

private extension ClaimableGiftDescriptionFactory {
    func calculateFee(
        partialDescription: PartialDescription,
        transactionId: GiftTransactionFeeId,
        assetStorageInfo: AssetStorageInfo
    ) {
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: transactionId.rawValue,
            payingIn: partialDescription.chainAsset.chainAssetId
        ) { [weak self] builder in
            guard let self else { return builder }

            let (newBuilder, _) = try transferCommandFactory.addingTransferCommand(
                to: builder,
                amount: partialDescription.giftAmountWithFee,
                recipient: partialDescription.claimingAccountId ?? transactionId.recepientAccountId,
                assetStorageInfo: assetStorageInfo
            )

            return newBuilder
        }
    }
}

// MARK: - ClaimableGiftDescriptionFactoryProtocol

extension ClaimableGiftDescriptionFactory: ClaimableGiftDescriptionFactoryProtocol {
    func createDescription(
        for claimableGift: ClaimableGiftInfo,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel,
        assetStorageInfo: @escaping () throws -> AssetStorageInfo
    ) -> BaseOperation<ClaimableGiftDescription> {
        AsyncClosureOperation { [weak self] completion in
            guard let self else {
                completion(.failure(BaseOperationError.parentOperationCancelled))
                return
            }

            mutex.lock()
            defer { mutex.unlock() }

            let chainAsset = claimableGift.chainAsset

            let onChainAmountWithFee: OnChainTransferAmount<BigUInt> = .all(value: giftAmountWithFee)

            let claimingWallet = try claimingWallet()
            let claimingAccountId = claimingWallet.fetch(
                for: chainAsset.chain.accountRequest()
            )?.accountId

            let transactionId = GiftTransactionFeeId(
                recepientAccountId: try claimingAccountId ?? chainAsset.chain.emptyAccountId(),
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
                assetStorageInfo: try assetStorageInfo()
            )
        }
    }
}

// MARK: - ExtrinsicFeeProxyDelegate

extension ClaimableGiftDescriptionFactory: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(
        result: Result<any ExtrinsicFeeProtocol, any Error>,
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
            let giftAmount = partialData.giftAmountWithFee.map { $0 - fee.amount }

            let description = ClaimableGiftDescription(
                seed: partialData.seed,
                accountId: partialData.accountId,
                amount: giftAmount,
                chainAsset: partialData.chainAsset,
                claimingAccountId: partialData.claimingAccountId
            )

            completion(.success(description))
        case let .failure(error):
            completion(.failure(error))
        }
    }
}

// MARK: - Private types

extension ClaimableGiftDescriptionFactory {
    typealias Completion = (Result<ClaimableGiftDescription, Error>) -> Void

    struct PartialDescription {
        let seed: Data
        let accountId: AccountId
        let chainAsset: ChainAsset
        let giftAmountWithFee: OnChainTransferAmount<BigUInt>
        let claimingAccountId: AccountId?
    }
}
