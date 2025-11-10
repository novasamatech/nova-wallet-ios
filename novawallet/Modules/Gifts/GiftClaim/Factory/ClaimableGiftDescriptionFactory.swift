import Foundation
import BigInt
import Operation_iOS

struct ClaimableGiftDescription {
    let seed: Data
    let amount: OnChainTransferAmount<BigUInt>
    let chainAsset: ChainAsset
    let claimingAccountId: AccountId

    func info() -> ClaimableGiftInfo {
        .init(
            seed: seed,
            chainId: chainAsset.chain.chainId,
            assetSymbol: chainAsset.asset.symbol
        )
    }
}

protocol ClaimableGiftDescriptionFactoryProtocol {
    func createDescription(
        for claimableGift: ClaimableGiftInfo,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel,
        assetStorageInfo: @escaping () throws -> AssetStorageInfo
    ) -> BaseOperation<ClaimableGiftDescription>
}

final class ClaimableGiftDescriptionFactory {
    let chainRegistry: ChainRegistryProtocol
    let transferCommandFactory: SubstrateTransferCommandFactory
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol

    var completions: [GiftTransactionFeeId: (PartialDescription, Completion)] = [:]

    let mutex = NSLock()

    init(
        chainRegistry: ChainRegistryProtocol,
        transferCommandFactory: SubstrateTransferCommandFactory,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.transferCommandFactory = transferCommandFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy

        self.feeProxy.delegate = self
    }
}

// MARK: - Private

private extension ClaimableGiftDescriptionFactory {
    func getChainAsset(
        for chainId: ChainModel.Id,
        assetSymbol: AssetModel.Symbol
    ) throws -> ChainAsset {
        let chain = try chainRegistry.getChainOrError(for: chainId)

        return try chain.chainAssetForSymbolOrError(assetSymbol)
    }

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
                recipient: partialDescription.claimingAccountId,
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

            let chainAsset = try getChainAsset(
                for: claimableGift.chainId,
                assetSymbol: claimableGift.assetSymbol
            )

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
        let chainAsset: ChainAsset
        let giftAmountWithFee: OnChainTransferAmount<BigUInt>
        let claimingAccountId: AccountId
    }
}
